const functions = require("firebase-functions/v2");
const admin = require("firebase-admin");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const Busboy = require("busboy");
const vision = require("@google-cloud/vision");

admin.initializeApp();
const db = admin.firestore();

// 방의 모든 멤버 조회 (통합 함수)
async function getAllRoomMembers(roomId) {
  try {
    // 1. Room의 memberIds 조회
    const roomDoc = await db.collection("Rooms").doc(roomId).get();
    const roomData = roomDoc.data() || {};
    const roomMemberIds = roomData.memberIds || [];
    const roomCreator = roomData.room_creator;

    // 2. RoomUser 컬렉션에서 활성 멤버 조회
    const roomUsers = await db
      .collection("RoomUser")
      .where("room_id", "==", roomId)
      .get();
    const roomUserIds = roomUsers.docs.map((doc) => doc.data().user_id);

    // 3. 모든 멤버 ID 통합 (중복 제거)
    const allMemberIds = new Set([
      ...roomMemberIds,
      ...roomUserIds,
      ...(roomCreator ? [roomCreator] : []), // 방 생성자 포함
    ]);

    return Array.from(allMemberIds);
  } catch (e) {
    console.error(`Error getting room members for ${roomId}:`, e);
    return [];
  }
}

// 냉장고의 모든 멤버 조회 (개선된 버전)
async function getAllRefrigeratorMembers(fridgeDoc) {
  try {
    const fridgeData = fridgeDoc.data() || {};
    const directMemberIds = fridgeData.member_ids || [];
    const roomId = fridgeData.room_id;

    // 냉장고에 직접 등록된 멤버들
    const allMembers = new Set(directMemberIds);

    // 방 연결 냉장고인 경우, 방의 모든 멤버도 포함
    if (roomId) {
      const roomMembers = await getAllRoomMembers(roomId);
      roomMembers.forEach((memberId) => allMembers.add(memberId));
    }

    return Array.from(allMembers);
  } catch (e) {
    console.error("Error getting refrigerator members:", e);
    return fridgeData.member_ids || [];
  }
}

// 매일 08:00~22:00 매 시간마다 실행 (사용자별 알림 시간 지원)
exports.dailyExpiryDigest = onSchedule(
  {
    schedule: "0 8-22 * * *", // 매 시간마다 실행
    timeZone: "Asia/Seoul",
    retryCount: 0,
  },
  async (event) => {
    try {
      const today = new Date();
      const currentHour = today.getHours();
      const ymd = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate());
      const todayStart = ymd(today);
      const tomorrowStart = new Date(
        todayStart.getTime() + 24 * 60 * 60 * 1000
      );

      console.log(`알림 체크 시작: ${currentHour}시`);

      // 모든 냉장고에서 오늘/내일 만료 식품 검색
      const refrigerators = await db.collection("Refrigerators").get();

      // 사용자별 집계 {uid: {today:[...], tomorrow:[...], notificationHour: X}}
      const userToExpiries = {};

      for (const fridgeDoc of refrigerators.docs) {
        // 개선된 멤버 조회 로직 사용
        const memberIds = await getAllRefrigeratorMembers(fridgeDoc);

        const compartmentsSnap = await fridgeDoc.ref
          .collection("compartments")
          .get();

        for (const compDoc of compartmentsSnap.docs) {
          const ingredientsSnap = await compDoc.ref
            .collection("ingredients")
            .get();
          for (const ingDoc of ingredientsSnap.docs) {
            const data = ingDoc.data() || {};
            const name = data.name || "식품";
            const expiryTs = data.expiryDate;
            if (!expiryTs) continue;
            const expiry = expiryTs.toDate();
            const expiryDateOnly = ymd(expiry).getTime();
            const todayOnly = todayStart.getTime();
            const tomorrowOnly = tomorrowStart.getTime();

            let bucket = null;
            if (expiryDateOnly === todayOnly) bucket = "today";
            else if (expiryDateOnly === tomorrowOnly) bucket = "tomorrow";
            if (!bucket) continue;

            for (const uid of memberIds) {
              if (!userToExpiries[uid])
                userToExpiries[uid] = { today: [], tomorrow: [] };
              userToExpiries[uid][bucket].push(name);
            }
          }
        }
      }

      // 사용자 fcmToken 및 알림 설정 읽고 전송
      const sendPromises = [];
      for (const [uid, buckets] of Object.entries(userToExpiries)) {
        const userDoc = await db.collection("Users").doc(uid).get();
        if (!userDoc.exists) continue;
        
        const userData = userDoc.data();
        const token = userData.fcmToken;
        if (!token) continue;

        // 사용자의 알림 시간 설정 확인 (기본값: 9시)
        const userNotificationHour = userData.notificationHour || 9;
        
        // 현재 시간이 사용자의 알림 시간과 일치하는지 확인
        if (currentHour !== userNotificationHour) {
          continue; // 알림 시간이 아니면 스킵
        }

        const parts = [];
        if (buckets.today.length)
          parts.push(
            `오늘 만료: ${buckets.today.slice(0, 5).join(", ")}${
              buckets.today.length > 5 ? " 외" : ""
            }`
          );
        if (buckets.tomorrow.length)
          parts.push(
            `내일 만료: ${buckets.tomorrow.slice(0, 5).join(", ")}${
              buckets.tomorrow.length > 5 ? " 외" : ""
            }`
          );
        const body = parts.join(" · ");
        if (!body) continue;

        const message = {
          token,
          notification: {
            title: "냉가드 유통기한 알림",
            body,
          },
          data: {
            type: "daily_expiry_digest",
          },
          android: {
            priority: "high",
            notification: {
              channelId: "expiration_alerts_channel",
            },
          },
        };

        sendPromises.push(admin.messaging().send(message));
      }

      await Promise.all(sendPromises);
      console.log(
        `${currentHour}시 알림 전송 완료. 전송된 사용자: ${sendPromises.length}명`
      );
    } catch (e) {
      console.error("dailyExpiryDigest error", e);
    }
  }
);

const GROQ_API_KEY = defineSecret("GROQ_API_KEY");

// 영수증 파싱 HTTP 엔드포인트 (이미지 업로드 → OCR → 간단 파싱 → Groq 정제)
exports.parseReceipt = onRequest(
  { cors: true, region: "asia-northeast3", secrets: [GROQ_API_KEY] },
  async (req, res) => {
    if (req.method !== "POST") {
      return res.status(405).json({ error: "Method Not Allowed" });
    }
    try {
      const busboy = Busboy({ headers: req.headers });
      const fileBuffers = [];
      let fileMime = "";
      let fileName = "receipt.jpg";

      await new Promise((resolve, reject) => {
        busboy.on("file", (fieldname, file, filename, encoding, mimetype) => {
          fileName = filename?.filename || filename || fileName;
          fileMime = mimetype;
          file.on("data", (data) => fileBuffers.push(data));
          file.on("end", () => {});
        });
        busboy.on("error", reject);
        busboy.on("finish", resolve);
        req.pipe(busboy);
      });

      if (!fileBuffers.length) {
        return res.status(400).json({ error: "No file uploaded" });
      }

      const buffer = Buffer.concat(fileBuffers);
      const client = new vision.ImageAnnotatorClient();
      const [result] = await client.textDetection({
        image: { content: buffer },
      });
      const detections = result.textAnnotations || [];
      const fullText = detections.length ? detections[0].description : "";

      // 매우 단순한 라인 기반 파싱 (필요시 강화)
      const lines = fullText
        .split("\n")
        .map((l) => l.trim())
        .filter(Boolean);
      const items = [];
      for (const line of lines) {
        // 예: "콜라 2 3000" → 상품명, 수량, 금액 형태 인식
        const m = line.match(/(.+?)\s+(\d{1,2})\s+(\d{3,})$/);
        if (m) {
          const name = m[1].trim();
          const qty = parseInt(m[2], 10);
          const price = parseInt(m[3], 10);
          if (name && qty > 0) {
            items.push({ name, quantity: qty, price });
          }
        } else {
          // 수량이 안 붙은 케이스: "우유 2500" or "사과"
          const m2 = line.match(/(.+?)\s+(\d{3,})$/);
          if (m2) {
            const name = m2[1].trim();
            const price = parseInt(m2[2], 10);
            if (name) items.push({ name, quantity: 1, price });
          } else if (
            /^[가-힣A-Za-z].{1,}$/.test(line) &&
            !/\d{4,}/.test(line)
          ) {
            // 텍스트만 있는 라인(숫자 큰 금액이 없는 경우): 일단 후보로 1개
            items.push({ name: line, quantity: 1 });
          }
        }
      }

      // 상점명/날짜/총액은 간단히 유추 (실서비스에선 정교화 권장)
      const storeName =
        lines.find((l) => l.length >= 2 && l.length <= 20) || "";
      const total = null;
      const date = new Date().toISOString();

      // Groq 정제 시도 (시크릿이 설정된 경우)
      try {
        const apiKey = GROQ_API_KEY.value();
        if (apiKey) {
          const prompt = buildGroqPrompt(fullText, items);
          const resp = await fetch(
            "https://api.groq.com/openai/v1/chat/completions",
            {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${apiKey}`,
              },
              body: JSON.stringify({
                model: "llama-3.1-8b-instant",
                messages: [{ role: "user", content: prompt }],
                temperature: 0.2,
                max_tokens: 800,
              }),
            }
          );

          if (resp.ok) {
            const data = await resp.json();
            const content = data?.choices?.[0]?.message?.content || "";
            const refined = parseGroqResponse(content);
            if (refined.length) {
              return res.json({
                store_name: storeName,
                date,
                total_amount: total,
                items: refined,
              });
            }
          } else {
            console.warn("Groq refine failed", await resp.text());
          }
        }
      } catch (e) {
        console.warn("Groq refine error", e);
      }

      // Groq 미사용/실패 시 기본 결과 반환
      return res.json({
        store_name: storeName,
        date,
        total_amount: total,
        items,
      });
    } catch (e) {
      console.error("parseReceipt error", e);
      return res.status(500).json({ error: String(e) });
    }
  }
);

function buildGroqPrompt(ocrText, basicItems) {
  const basic = (basicItems || [])
    .map((it) => `${it.name}|${it.quantity}`)
    .join("\n");
  return `영수증 OCR 텍스트를 분석해서 진짜 음식/상품만 정확히 추출해주세요.

=== OCR 원본 텍스트 ===
${ocrText}

=== 현재 추출된 항목들 ===
${basic}

=== 요청사항 ===
1. 진짜 음식/상품만 선별
2. 표 헤더/합계/결제/매장정보 등 제외
3. 수량 정확히
4. 아래 형식으로만 답변(추가 설명 금지):
상품명1|수량1
상품명2|수량2`;
}

function parseGroqResponse(text) {
  const lines = String(text)
    .split("\n")
    .map((l) => l.trim())
    .filter(Boolean);
  const items = [];
  for (const line of lines) {
    if (!line.includes("|")) continue;
    const [nameRaw, qtyRaw] = line.split("|");
    const name = (nameRaw || "").trim();
    const qty = parseInt((qtyRaw || "1").trim(), 10) || 1;
    if (name) items.push({ name, quantity: qty });
  }
  return items;
}

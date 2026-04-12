import apn from 'apn';

let provider: apn.Provider | null = null;

function getProvider(): apn.Provider | null {
  if (provider) return provider;

  const keyContent = process.env.APNS_KEY_CONTENT;
  const keyId = process.env.APNS_KEY_ID;
  const teamId = process.env.APNS_TEAM_ID;

  if (!keyContent || !keyId || !teamId) {
    // 証明書未設定時は通知をスキップ（開発時）
    return null;
  }

  provider = new apn.Provider({
    token: {
      key: keyContent,
      keyId,
      teamId,
    },
    production: process.env.NODE_ENV === 'production',
  });

  return provider;
}

/**
 * APNs プッシュ通知送信
 * 証明書未設定時はコンソールログのみ（開発時フォールバック）
 */
export async function sendPushNotification(
  deviceToken: string,
  title: string,
  body: string,
  data?: Record<string, unknown>
): Promise<void> {
  const p = getProvider();

  if (!p) {
    console.log(`[APNs dev] → ${deviceToken.slice(0, 8)}... | ${title}: ${body}`);
    return;
  }

  const notification = new apn.Notification();
  notification.alert = { title, body };
  notification.sound = 'default';
  notification.badge = 1;
  notification.topic = process.env.APNS_BUNDLE_ID || 'com.realmatching.app';
  if (data) notification.payload = data;

  try {
    const result = await p.send(notification, deviceToken);
    if (result.failed.length > 0) {
      console.error('APNs send failed:', result.failed);
    }
  } catch (error) {
    console.error('APNs error:', error);
  }
}

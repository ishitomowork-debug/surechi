import nodemailer from 'nodemailer';

function createTransport() {
  const { SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS } = process.env;

  if (SMTP_HOST && SMTP_USER && SMTP_PASS) {
    return nodemailer.createTransport({
      host: SMTP_HOST,
      port: parseInt(SMTP_PORT || '587'),
      secure: false,
      auth: { user: SMTP_USER, pass: SMTP_PASS },
    });
  }

  // 未設定時はコンソールにログ出力（開発用）
  return nodemailer.createTransport({
    jsonTransport: true,
  });
}

export async function sendEmail(to: string, subject: string, html: string) {
  const transporter = createTransport();
  const from = process.env.SMTP_FROM || 'noreply@realmatching.app';

  const info = await transporter.sendMail({ from, to, subject, html });

  if (!process.env.SMTP_HOST) {
    console.log(`[DEV MAIL] To: ${to} | Subject: ${subject}`);
    console.log('[DEV MAIL] Body:', html.replace(/<[^>]+>/g, ''));
  }

  return info;
}

export async function sendVerificationEmail(to: string, token: string) {
  const frontendUrl = process.env.FRONTEND_URL || 'http://localhost:3000';
  const link = `surechi://verify-email?token=${token}`;
  await sendEmail(
    to,
    'メールアドレスの確認 - スレチ',
    `<p>スレチへようこそ！</p>
    <p>以下のリンクをクリックしてメールアドレスを確認してください：</p>
    <a href="${link}">${link}</a>
    <p>このリンクは24時間有効です。</p>`
  );
}

export async function sendPasswordResetEmail(to: string, token: string) {
  const frontendUrl = process.env.FRONTEND_URL || 'http://localhost:3000';
  const link = `${frontendUrl}/reset-password?token=${token}`;
  await sendEmail(
    to,
    'パスワードリセット - スレチ',
    `<p>パスワードリセットのリクエストを受け付けました。</p>
    <p>以下のリンクをクリックして新しいパスワードを設定してください：</p>
    <a href="${link}">${link}</a>
    <p>このリンクは1時間有効です。リクエストした覚えがない場合は無視してください。</p>`
  );
}

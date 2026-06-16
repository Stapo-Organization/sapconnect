// build-pdf.mjs — يحوّل دليل المتجر HTML إلى PDF احترافي عبر Google Chrome المثبّت.
// التشغيل:  node docs/build-pdf.mjs
// يستخدم puppeteer-core ليقود Chrome نفسه (تشكيل عربي سليم عبر Blink) مع هوامش A4
// وتذييل عربي وأرقام صفحات وطباعة الخلفيات. لا يُنزّل Chromium منفصلاً.

import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const htmlPath = join(__dirname, 'muntajat-store-guide.html');
const pdfPath = join(__dirname, 'muntajat-store-guide.pdf');

const CHROME_CANDIDATES = [
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary',
  '/Applications/Chromium.app/Contents/MacOS/Chromium',
];
const executablePath = CHROME_CANDIDATES.find(existsSync);
if (!executablePath) {
  console.error('لم يُعثر على Google Chrome. ثبّته أو عدّل المسار في CHROME_CANDIDATES.');
  process.exit(1);
}

const puppeteer = await import('puppeteer-core').then(m => m.default ?? m);

const browser = await puppeteer.launch({ executablePath, headless: 'new', args: ['--no-sandbox'] });
const page = await browser.newPage();
await page.goto('file://' + htmlPath, { waitUntil: 'networkidle0', timeout: 60000 });
await page.evaluateHandle('document.fonts.ready'); // انتظار تحميل خط Cairo قبل الالتقاط

const footer = `<div style="font-family:Cairo,sans-serif;font-size:8px;width:100%;text-align:center;color:#94A3B8;direction:rtl">
  منتجات · سرّي — صفحة <span class="pageNumber"></span> من <span class="totalPages"></span></div>`;
const header = `<div style="font-family:Cairo,sans-serif;font-size:8px;width:100%;text-align:center;color:#CBD5E1;direction:rtl">
  دليل تجربة متجر منتجات</div>`;

await page.pdf({
  path: pdfPath,
  format: 'A4',
  printBackground: true,
  displayHeaderFooter: true,
  headerTemplate: header,
  footerTemplate: footer,
  margin: { top: '18mm', bottom: '20mm', left: '16mm', right: '16mm' },
});

await browser.close();
console.log('تم إنشاء PDF: ' + pdfPath);

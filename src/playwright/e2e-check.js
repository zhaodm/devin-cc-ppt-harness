const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

async function runCheck(htmlPath, screenshotDir) {
  const absolutePath = path.resolve(htmlPath);
  if (!fs.existsSync(absolutePath)) {
    console.log(JSON.stringify({ status: 'FAIL', error: '文件不存在: ' + absolutePath, checks: [] }));
    process.exit(1);
  }

  if (screenshotDir && !fs.existsSync(screenshotDir)) {
    fs.mkdirSync(screenshotDir, { recursive: true });
  }

  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  await page.setViewportSize({ width: 1280, height: 720 });

  const checks = [];

  try {
    await page.goto('file://' + absolutePath, { waitUntil: 'networkidle' });

    const slide = await page.$('.slide');
    if (slide) {
      const box = await slide.boundingBox();
      checks.push({
        name: '16:9容器存在',
        pass: true
      });
      checks.push({
        name: '容器宽度1280',
        pass: Math.abs(box.width - 1280) < 2
      });
      checks.push({
        name: '容器高度720',
        pass: Math.abs(box.height - 720) < 2
      });
    } else {
      checks.push({ name: '16:9容器存在', pass: false, detail: '未找到 .slide 元素' });
    }

    const header = await page.$('.slide-header h1');
    if (header) {
      const text = await header.textContent();
      checks.push({ name: 'slide-header存在', pass: true });
      checks.push({ name: '标题非空', pass: text.trim().length > 0 });
    } else {
      checks.push({ name: 'slide-header存在', pass: false });
      checks.push({ name: '标题非空', pass: false });
    }

    const keypoint = await page.$('.slide-keypoint');
    if (keypoint) {
      const text = await keypoint.textContent();
      checks.push({ name: 'slide-keypoint存在', pass: true });
      checks.push({ name: '重点行非空', pass: text.trim().length > 0 });
    } else {
      checks.push({ name: 'slide-keypoint存在', pass: false });
      checks.push({ name: '重点行非空', pass: false });
    }

    const body = await page.$('.slide-body');
    checks.push({ name: 'slide-body存在', pass: body !== null });

    const hasHOverflow = await page.evaluate(() => {
      const s = document.querySelector('.slide');
      return s ? s.scrollWidth > s.clientWidth : false;
    });
    checks.push({ name: '无水平溢出', pass: !hasHOverflow });

    const hasVOverflow = await page.evaluate(() => {
      const s = document.querySelector('.slide');
      return s ? s.scrollHeight > s.clientHeight : false;
    });
    checks.push({ name: '无垂直溢出', pass: !hasVOverflow });

    const cards = await page.$$('.card');
    if (cards.length > 0) {
      for (let i = 0; i < cards.length; i++) {
        const title = await cards[i].$('.card-title');
        if (title) {
          const text = await title.textContent();
          checks.push({ name: '卡片' + (i + 1) + '标题非空', pass: text.trim().length > 0 });
        }
      }
    }

    const mermaidBlocks = await page.$$('.mermaid');
    if (mermaidBlocks.length > 0) {
      await page.waitForTimeout(3000);
      const rendered = await page.$('.mermaid svg');
      checks.push({ name: 'Mermaid图表已渲染', pass: rendered !== null });
    }

    const screenshotName = path.basename(htmlPath, '.html') + '.png';
    const screenshotPath = screenshotDir
      ? path.join(screenshotDir, screenshotName)
      : path.join(path.dirname(absolutePath), screenshotName);

    await page.screenshot({ path: screenshotPath, fullPage: false });

    const allPass = checks.every(c => c.pass);
    const result = {
      status: allPass ? 'PASS' : 'FAIL',
      file: htmlPath,
      checks: checks,
      screenshot: screenshotPath,
      summary: checks.filter(c => c.pass).length + '/' + checks.length
    };

    console.log(JSON.stringify(result, null, 2));
    process.exit(allPass ? 0 : 1);

  } catch (err) {
    console.log(JSON.stringify({ status: 'FAIL', error: err.message, checks: checks }));
    process.exit(1);
  } finally {
    await browser.close();
  }
}

const args = process.argv.slice(2);
if (args.length === 0) {
  console.error('用法: node e2e-check.js <html文件路径> [截图目录]');
  process.exit(1);
}

runCheck(args[0], args[1]);

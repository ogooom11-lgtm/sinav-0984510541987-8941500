// Optional real-browser check: install playwright and @sparticuz/chromium.
process.env.AWS_EXECUTION_ENV='AWS_Lambda_nodejs22.x';
const {chromium}=require('playwright'),binary=require('@sparticuz/chromium').default,assert=require('node:assert/strict');
(async()=>{
 const browser=await chromium.launch({executablePath:await binary.executablePath(),args:binary.args,headless:true});
 const page=await browser.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto(process.env.BASIRA_PREVIEW_URL||'http://localhost:3000');await page.waitForSelector('.card');
 for(const width of [320,390,768,1440]){
  await page.setViewportSize({width,height:900});assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'home overflow '+width);
 }
 await page.locator('[data-action^="lesson:"]').first().click();await page.waitForSelector('.fact');
 await page.locator('[data-action="practice"]').click();await page.waitForSelector('.option');
 const correct=await page.evaluate(()=>engine.session.options.indexOf(engine.current().answer));
 await page.locator('.option').nth((correct+1)%3).click();await page.waitForSelector('.feedback');
 assert((await page.locator('.feedback').innerText()).includes('غير صحيحة'));
 assert.equal(await page.locator('.option:not([disabled])').count(),0);
 for(const width of [320,390,768,1440]){
  await page.setViewportSize({width,height:900});assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'quiz overflow '+width);
 }
 const before=await page.evaluate(()=>JSON.stringify(engine.session));await page.reload();await page.waitForSelector('[data-action="resume"]');
 await page.locator('[data-action="resume"]').click();assert.equal(await page.evaluate(()=>JSON.stringify(engine.session)),before);
 await page.locator('[data-action="next"]').click();assert.equal(await page.locator('.feedback').count(),0);
 assert.deepEqual(errors,[]);await browser.close();console.log('PASS Chromium lessons: four widths, instant incorrect feedback, locking, persisted resume, no runtime errors');
})().catch(e=>{console.error(e);process.exit(1)});

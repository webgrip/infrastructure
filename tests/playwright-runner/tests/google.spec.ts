import { test, expect } from '@playwright/test';

test('Google home page loads', async ({ page }) => {
    await page.goto('https://www.google.com');
    const title = await page.title();
    expect(title).toContain('Google');
});
/**
 * WebDriverIO Cucumber Configuration File
 * Company: AlgoShack Technologies Pvt Ltd
 * Supports:
 * - Dynamic browser setup
 * - Video and screenshot capturing
 * - HTML and Allure reporting
 * - API scenario detection
 */

import cucumberHtmlReporter from 'cucumber-html-reporter';
import Video from 'wdio-video-reporter';
import fs from 'fs';
import path from 'path';
import commonUtil from './common/common-util.js';
import { spawn, execSync } from 'child_process';
import { glob } from 'glob';

/**
 * @description Read test settings from XML configuration file
 */
const BROWSER = commonUtil.getXmlData('BrowserType').trim().toLowerCase();
const STORESTEPSCREENSHOTS = commonUtil.getXmlData('storeStepScreenshots').trim().toLowerCase();
const SUCCESSCAPTUREVIDEO = commonUtil.getXmlData('EnableVideoCaptureForSuccess').trim().toLowerCase() === 'true';
const FAILURECAPTUREVIDEO = commonUtil.getXmlData('EnableVideoCaptureForFailure').trim().toLowerCase() === 'true';
const ENABLEFILEDOWNLOAD = commonUtil.getXmlData('DownloadInCurrentDirectory').trim().toLowerCase() === 'true';
const isIncognitoEnabled = commonUtil.getXmlData('EnableIncognito').trim().toLowerCase() === 'true';
const BROWSERTYPE = BROWSER.replace('headless', '').trim();

/**
 * @description Detect if test contains API scenarios (tagged with @api)
 */
const FEATUREFILES = await glob('./features/**/*.feature');
let isApiTest = false;
for (const file of FEATUREFILES) {
    const content = fs.readFileSync(file, 'utf8');
    if (content.toLowerCase().includes('@api')) {
        isApiTest = true;
        break;
    }
}

export { isApiTest };

export const config = {
    runner: 'local',

    specs: ['./features/**/*.feature'],
    maxInstances: 10,

    capabilities: !isApiTest ? [
        {
            maxInstances: 1,
            browserName: BROWSERTYPE,
            acceptInsecureCerts: true,

            ...(BROWSER.includes('chrome') && {
                'goog:chromeOptions': {
                    args: [
                        ...(BROWSER.includes('headless') ? ['--headless=new'] : []),
                        '--disable-gpu',
                        '--window-size=1280,800',
                        '--no-sandbox',
                        '--disable-dev-shm-usage',
                        ...(isIncognitoEnabled ? ['--incognito'] : []),
                        // ✅ unique user-data-dir to fix session errors
                        `--user-data-dir=/tmp/chrome-user-data-${Date.now()}`,
                    ],
                    ...(ENABLEFILEDOWNLOAD && {
                        prefs: {
                            'download.default_directory': path.resolve(process.cwd()),
                            'download.prompt_for_download': false,
                            'directory_upgrade': true,
                            'safebrowsing.enabled': true
                        }
                    })
                }
            }),

            ...(BROWSER.includes('firefox') && {
                'moz:firefoxOptions': {
                    args: [
                        ...(BROWSER.includes('headless') ? ['-headless'] : []),
                        ...(isIncognitoEnabled ? ['--private-window'] : [])
                    ],
                }
            }),

            ...(BROWSER.includes('edge') && {
                'ms:edgeOptions': {
                    args: [
                        ...(BROWSER.includes('headless') ? ['--headless'] : []),
                        '--disable-gpu',
                        '--window-size=1280,800',
                        ...(isIncognitoEnabled ? ['--inprivate'] : [])
                    ]
                }
            })
        }
    ] : [
        {
            maxInstances: 1,
            browserName: BROWSERTYPE,
            acceptInsecureCerts: true,
            'goog:chromeOptions': {
                args: [
                    '--headless=new',
                    '--disable-gpu',
                    '--window-size=1280,800',
                    '--disable-dev-shm-usage',
                    '--no-sandbox',
                    '--remote-debugging-port=9222',
                    `--user-data-dir=/tmp/chrome-user-data-${Date.now()}`
                ],
            },
        },
    ],

    services: [
        ['chromedriver', {
            chromedriverCustomPath: '/usr/local/bin/chromedriver'
        }]
    ],

    logLevel: 'info',
    baseUrl: 'http://localhost',
    waitforTimeout: 10000,
    connectionRetryTimeout: 120000,
    connectionRetryCount: 3,
    framework: 'cucumber',

    reporters: [
        'spec',
        ...(SUCCESSCAPTUREVIDEO || FAILURECAPTUREVIDEO ? [[Video, {
            saveAllVideos: true,
            videoSlowdownMultiplier: 3,
            outputDir: './videos'
        }]] : []),
        [
            'cucumberjs-json',
            {
                jsonFolder: './reports/json',
                language: 'en',
            },
        ],
        ['allure', {
            outputDir: 'allure-results',
            disableWebdriverScreenshots: false,
            useCucumberStepReporter: true,
            disableWebdriverStepsReporting: true,
        }]
    ],

    cucumberOpts: {
        require: ['./stepdefinitions/**/*.js', './common/**/*.js'],
        timeout: 60000,
    },

    onPrepare: async () => {
        const videoDir = './videos';
        if (fs.existsSync(videoDir)) {
            fs.rmSync(videoDir, { recursive: true, force: true });
            console.log(`Deleted folder: ${videoDir}`);
        }

        const directories = ['./reports/json/', './reports/report/'];
        for (const dir of directories) {
            if (!fs.existsSync(dir)) {
                fs.mkdirSync(dir, { recursive: true });
                console.log(`Created folder: ${dir}`);
            }
        }

        const reportDir = './reports/json/';
        const files = fs.readdirSync(reportDir).filter(file => file.endsWith('.json'));
        for (const file of files) {
            fs.unlinkSync(path.join(reportDir, file));
        }

        const allureResultsDir = path.resolve('allure-results');
        if (fs.existsSync(allureResultsDir)) {
            fs.rmSync(allureResultsDir, { recursive: true, force: true });
        }
    },

    onComplete: async () => {
        try {
            if (browser.sessionId) {
                await browser.deleteSession();
            }
        } catch (e) {
            console.warn('Error deleting browser session:', e.message);
        }

        const reportDir = './reports/json/';
        const jsonFiles = fs.readdirSync(reportDir).filter(file => file.endsWith('.json'));

        if (jsonFiles.length) {
            const jsonFilePath = path.join(reportDir, jsonFiles[0]);
            cucumberHtmlReporter.generate({
                theme: 'bootstrap',
                jsonFile: jsonFilePath,
                output: `./reports/report/cucumber_reporter_${Date.now()}.html`,
                reportSuiteAsScenarios: true,
                screenshotsDirectory: './reports/screenshots',
                storeScreenshots: STORESTEPSCREENSHOTS === 'true',
                metadata: {
                    'App Version': '1.0.0',
                    'Test Environment': 'STAGING',
                    Browser: BROWSERTYPE,
                    Platform: 'Windows 10',
                },
            });
        }

        /**
         * Generate Allure report safely without trying to open GUI
         */
        const allureResultsDir = path.resolve('allure-results');
        const allureReportDir = path.resolve('allure-report');

        if (fs.existsSync(allureResultsDir)) {
            execSync(`allure generate ${allureResultsDir} --clean -o ${allureReportDir}`);
            console.log(`Allure report generated at: ${allureReportDir}`);
            console.log(`You can serve it manually: allure open ${allureReportDir}`);
        }

        // Optional post-processing
        try {
            execSync('node allurepath.js');
        } catch (e) {
            console.warn('Allure path post-processing skipped:', e.message);
        }
    },
};

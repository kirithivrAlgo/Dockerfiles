# pylint: disable=missing-module-docstring,missing-function-docstring,broad-exception-raised,broad-exception-caught,line-too-long,no-member
import os
import shutil
import subprocess
import threading
import tempfile
from datetime import datetime
import cv2
import numpy as np
import xmltodict
import yaml
from selenium import webdriver
from selenium.webdriver.chrome.options import Options as ChromeOptions
from selenium.webdriver.chrome.service import Service as ChromeService
from selenium.webdriver.edge.options import Options as EdgeOptions
from selenium.webdriver.edge.service import Service as EdgeService
from selenium.webdriver.firefox.options import Options as FirefoxOptions
from selenium.webdriver.firefox.service import Service as FirefoxService
from webdriver_manager.chrome import ChromeDriverManager
from webdriver_manager.firefox import GeckoDriverManager
from webdriver_manager.microsoft import EdgeChromiumDriverManager
from steps import AutoHealUtil


def before_all(context):
    def getymldata(file):
        return yaml.safe_load(file)

    starttime = datetime.now()
    print("before all method")

    # Load test data
    try:
        test_data_path = os.path.abspath(os.path.join(os.path.dirname(__file__), 'TestData.yml'))
        with open(test_data_path, 'r', encoding='utf-8') as file:
            context.yamldata = str(getymldata(file))
    except FileNotFoundError:
        context.yamldata = None

    # Load object repo
    try:
        object_repo_path = os.path.abspath(os.path.join(os.path.dirname(__file__), 'ObjectRepository.yml'))
        with open(object_repo_path, 'r', encoding='utf-8') as file:
            context.yamldataobject = str(getymldata(file))
    except FileNotFoundError:
        context.yamldataobject = None

    # Default Chrome options
    chrome_options = webdriver.ChromeOptions()
    chrome_options.add_argument('--disable-extensions')
    chrome_options.add_argument('--disable-notifications')
    chrome_options.add_argument('--disable-application-cache')
    chrome_options.add_argument('--no-sandbox')
    chrome_options.add_argument('--disable-dev-shm-usage')
    chrome_options.add_argument('--remote-debugging-port=0')
    chrome_options.add_argument(f"--user-data-dir={tempfile.mkdtemp()}")
    chrome_options.add_experimental_option('w3c', False)
    context.chromeoptions = chrome_options

    # Load ApplicationSettings.xml
    xml_path = os.path.abspath(os.path.join(os.path.dirname(__file__), 'ApplicationSettings.xml'))
    with open(xml_path) as fd:
        xml_data = xmltodict.parse(fd.read())

    context.autName = xml_data['ApplicationSettings']['URL']
    context.browserName = xml_data['ApplicationSettings']['browserName']
    context.compareImage = xml_data['ApplicationSettings']['EnableCompareImage']
    context.FailureScreenshot = xml_data['ApplicationSettings']['EnableScrenshotForFailure']
    context.PassedScreenshot = xml_data['ApplicationSettings']['EnableScrenshotForSucess']
    context.AllStepsScreenshot = xml_data['ApplicationSettings']['EnableScrenshotForAllSteps']
    context.recording1 = xml_data['ApplicationSettings']['EnableVideoCaptureForSucess']
    context.recording2 = xml_data['ApplicationSettings']['EnableVideoCaptureForFailure']
    context.ParallelExecution = xml_data['ApplicationSettings']['ParallelExecution']
    context.SeparateFailureReport = xml_data['ApplicationSettings']['EnableSeprateFailureReport']
    context.ReportFolder = xml_data['ApplicationSettings']['ReportFolder']
    context.Incognito = xml_data['ApplicationSettings']['Incognito']
    context.MaximumTimeInSecondsToWaitForControl = xml_data['ApplicationSettings']['MaximumTimeInSecondsToWaitForControl']
    context.MaximumTimeInMilliSecondsToWaitForPage = xml_data['ApplicationSettings']['MaximumTimeInMilliSecondsToWaitForPage']
    context.URL = xml_data['ApplicationSettings']['URL']
    context.FileDownload = xml_data['ApplicationSettings']['EnableFileDownload']
    context.BrowserType = xml_data['ApplicationSettings']['BrowserType']
    context.softAssertion = xml_data['ApplicationSettings']['EnableSoftAssertion']
    context.AutomationType = xml_data['ApplicationSettings']['AutomationType']
    context.WebdriverPath = xml_data['ApplicationSettings']['WebdriverPath']
    context.TestEnvironment = xml_data['ApplicationSettings']['testEnvironment']
    context.browserVersion = xml_data['ApplicationSettings']['browserVersion']
    context.platformName = xml_data['ApplicationSettings']['platformName']
    context.UserName = xml_data['ApplicationSettings']['LT_USERNAME']
    context.AccessKey = xml_data['ApplicationSettings']['LT_ACCESS_KEY']

    # Logs
    os_version, user = "", ""
    report_dir = os.path.join(os.getcwd(), context.ReportFolder)
    print(os.path.isdir(report_dir),"directory exist")
    screenshots_dir = os.path.join(report_dir, "screenshots")
    print(screenshots_dir,"screenshot dir")
    os.makedirs(screenshots_dir,  mode=0o777, exist_ok=True)
    print(os.getcwd(),"current directory and ")
    print(os.path.isdir(report_dir),"directory exist")
    print("path-----------------",)
    context.LogFile = os.path.join(report_dir, "Report.txt")
    with open(context.LogFile, "w+", encoding="utf-8") as f:
        f.write(f"Start_Time= {starttime}")
        f.write(f"\nOS={os_version}")
        f.write(f"\nUser={user}")
        f.write(f"\nautName={context.autName}")
        f.write(f"\nFailureScreenshot={context.FailureScreenshot}")
        f.write(f"\nSuccessScreenshot={context.PassedScreenshot}")
        f.write(f"\nAllStepScreenshot={context.AllStepsScreenshot}")
        f.write(f"\nseparateFailReport={context.SeparateFailureReport}")

    # Defaults
    context.list_tags = []
    context.status = ''
    context.scenarioName = ''
    context.TimeIntervalInMilliSeconds = 1
    context.dict_api_response = {}
    context.eachStepMessage = []
    context.WebCopiedList = []
    context.WebCopiedKey = {}
    context.softFailurelist = []


def after_scenario(context, scenario):
    try:
        if context.recording1.upper() == "TRUE" or context.recording2.upper() == "TRUE":
            stop_recording(context)
        if context.recording2.upper() == "TRUE" and scenario.status == 'passed':
            delete_recorded_file(context)
    except Exception as e:
        print(f"Error stopping recording: {str(e)}")

    try:
        if context.status == 'failed':
            context.driver.quit()
            context.status = ''
        else:
            for i in scenario.tags:
                if "set2" in i or "set3" in i:
                    context.driver.quit()
                    break
    except Exception:
        pass

    if context.WebCopiedList:
        context.WebCopiedList.clear()


def before_scenario(context, scenario):
    browser = str(context.BrowserType).lower()
    headless = "headless" in browser
    implicit_wait_time = int(context.MaximumTimeInMilliSecondsToWaitForPage)
    download_dir = os.getcwd() if str(context.FileDownload).lower() == "true" else None
    driver_path = context.WebdriverPath
    tags = [tag.lower() for tag in scenario.tags]
    if any("api" in tag for tag in tags):
        headless = True

    # Cloud execution
    if context.TestEnvironment == 'lambdatest':
        options = webdriver.ChromeOptions()
        options.set_capability = {
            'build': 'LambdaTest Web Automation',
            'w3c': True,
            'platformName': context.platformName,
            'browserName': context.browserName,
            'browserVersion': context.browserVersion,
        }
        url = f"https://{context.UserName}:{context.AccessKey}@hub.lambdatest.com/wd/hub"
        context.driver = webdriver.Remote(url, options=options)

    elif context.TestEnvironment == 'browserstack':
        url = f"http://{context.UserName}:{context.AccessKey}@hub-cloud.browserstack.com/wd/hub"
        options = webdriver.ChromeOptions()
        options.set_capability = {
            'platformName': context.platformName,
            'browserName': context.browserName,
            'browserVersion': context.browserVersion}
        context.driver = webdriver.Remote(command_executor=url, options=options)

    # Local drivers
    else:
        # Fix driver paths cross-platform
        if driver_path and "na" not in driver_path.lower():
            if "firefox" in browser:
                driver_path = os.path.join(driver_path, "geckodriver")
            elif "edge" in browser:
                driver_path = os.path.join(driver_path, "msedgedriver")
            else:
                driver_path = os.path.join(driver_path, "chromedriver")
        else:
            driver_path = None

        if "firefox" in browser:
            context.firefox_options = FirefoxOptions()
            if headless:
                context.firefox_options.add_argument("--headless")
            if download_dir:
                profile = webdriver.FirefoxProfile()
                profile.set_preference("browser.download.folderList", 2)
                profile.set_preference("browser.download.dir", download_dir)
                profile.set_preference("browser.helperApps.neverAsk.saveToDisk", "application/pdf")
                profile.set_preference("pdfjs.disabled", True)
                context.firefox_options.profile = profile
            service = FirefoxService(executable_path=driver_path) if driver_path and os.path.exists(driver_path) else FirefoxService(GeckoDriverManager().install())
            context.driver = webdriver.Firefox(service=service, options=context.firefox_options)

        elif "edge" in browser:
            context.edge_options = EdgeOptions()
            if headless:
                context.edge_options.add_argument("--headless")
            context.edge_options.use_chromium = True
            if download_dir:
                context.edge_options.add_experimental_option('prefs', {
                    "download.default_directory": download_dir,
                    "download.prompt_for_download": False,
                    "directory_upgrade": True,
                    "safebrowsing.enabled": True
                })
            service = EdgeService(executable_path=driver_path) if driver_path and os.path.exists(driver_path) else EdgeService(EdgeChromiumDriverManager().install())
            context.driver = webdriver.Edge(service=service, options=context.edge_options)

        else:  # Chrome
            context.chrome_options = ChromeOptions()
            if str(context.Incognito).lower() == "true":
                context.chrome_options.add_argument('--incognito')
            context.chrome_options.set_capability("goog:loggingPrefs", {"performance": "ALL"})
            context.chrome_options.add_experimental_option("perfLoggingPrefs", {"enableNetwork": True})
            context.chrome_options.add_argument('--no-sandbox')
            context.chrome_options.add_argument('--disable-dev-shm-usage')
            context.chrome_options.add_argument('--remote-debugging-port=0')
            context.chrome_options.add_argument(f"--user-data-dir={tempfile.mkdtemp()}")
            if headless:
                context.chrome_options.add_argument("--headless=new")
            if download_dir:
                context.chrome_options.add_experimental_option('prefs', {
                    "download.default_directory": download_dir,
                    "download.prompt_for_download": False,
                    "directory_upgrade": True,
                    "safebrowsing.enabled": True
                })
            service = ChromeService(executable_path=driver_path) if driver_path and os.path.exists(driver_path) else ChromeService(ChromeDriverManager().install())
            context.driver = webdriver.Chrome(service=service, options=context.chrome_options)

    # Defaults per scenario
    context.driver.implicitly_wait(implicit_wait_time)
    try:
        context.driver.maximize_window()
    except Exception:
        pass
    context.ParentWindowHandle = context.driver.current_window_handle
    context.eachStepMessage = []
    context.StepNumber = 0
    context.list_tags = scenario.tags
    context.scenarioName = scenario.name
    context.list_tag = ""
    for i in context.list_tags:
        if "test" in i:
            context.list_tag = i

    if context.recording1.upper() == "TRUE" or context.recording2.upper() == "TRUE":
        start_recording(context)


def before_step(context, step):
    context.current_step = step


def after_step(context, step):
    context.StepNumber += 1
    with open(context.LogFile, "a+", encoding="utf-8") as f:
        f.write("\n" + str(context.list_tags))
        f.write("\n" + str(context.scenarioName))
        f.write("\n" + str(step) + "StepNumber|" + str(context.StepNumber) + "|StepNumber")

        # Screenshots
        if context.AllStepsScreenshot == "True":
            save_step_screenshot(context, f)
        else:
            if context.FailureScreenshot == "True" and step.status == 'failed':
                save_step_screenshot(context, f)
            if context.PassedScreenshot == "True" and "then" in str(step).lower() and step.status == 'passed':
                save_step_screenshot(context, f)

        # Step messages
        if context.eachStepMessage:
            for message in context.eachStepMessage:
                f.write("\nMessage|" + message.replace("\n", " ").replace("\r", " ") + "|Message")
            context.eachStepMessage.clear()

    if step.status == 'failed' and context.list_tags:
        AutoHealUtil.save_config_details(context.list_tags[0], context)


def save_step_screenshot(context, file_handle):
    date = str(datetime.now()).replace(' ', '').replace('-', '').replace(':', '').replace('.', '')
    img = context.list_tag + '_' + date
    tempimage = os.path.join(context.ReportFolder, 'screenshots', img + '.png')
    context.driver.save_screenshot(os.path.join(os.getcwd(), tempimage))
    file_handle.write("\nscreenshot|" + img + ".png|screenshot")


def after_all(context):
    endtime = datetime.now()
    with open(context.LogFile, "a+", encoding='utf-8') as f:
        f.write(f"\nEnd_Time={endtime}")

    try:
        reportfolder = os.path.join(os.getcwd(), context.ReportFolder)
        os.makedirs(reportfolder, exist_ok=True)

        finalreportfile = os.path.join(os.getcwd(),"TestReports", "TestReport_" + datetime.now().strftime('%Y-%m-%d_%H-%M-%S'))
        os.makedirs(finalreportfile, exist_ok=True)

        oldpath = os.path.join(os.getcwd(), "temp")
        if os.path.exists(oldpath):
            print("old path exist",oldpath)
            for file_name in os.listdir(oldpath):
                print("file name-----------------------",file_name)
                print("moving old file to new file",os.path.join(oldpath, file_name),"---------->",finalreportfile)
                shutil.move(os.path.join(oldpath, file_name), finalreportfile)
            shutil.rmtree(oldpath, ignore_errors=True)

        reportpath = os.path.join(finalreportfile, "report.html")
        algo_report_exe_path = os.path.join(os.getcwd(), "algoReport.exe")
        pdf_report_exe_path = os.path.join(os.getcwd(), "pdfReport.exe")
        print(algo_report_exe_path,"algo_report_exe_path",os.path.exists(algo_report_exe_path))
        if os.path.exists(algo_report_exe_path):
            print("os path exist for algo_report_exe_path")
            if shutil.which("mono"):
                print("shutil mono passed")
                output = subprocess.run(["mono", "algoReport.exe", "behave", finalreportfile, reportpath], shell=False, check=True)
                print(output,"subprocess output")
                json_files = [f for f in os.listdir(finalreportfile) if f.endswith(".json")]
                print(json_files)
                if json_files and os.path.exists(pdf_report_exe_path):
                    subprocess.run(["mono","pdfReport.exe", reportpath], shell=False, check=True)
                else:
                    print("no json file")
            else:
                print("⚠️ Skipping algoReport.exe execution (mono not available in Linux Docker).")

 
    except Exception as e:
        print(f"Exception------------ {e}")


# --- Recording helpers ---
def start_recording(context):
    try:
        if not os.environ.get("DISPLAY"):
            print("🚫 Skipping screen recording (no DISPLAY found).")
            return
        import pyautogui
        name = str(context.scenarioName).replace(" ", '_')
        screenrecording_dir = os.path.join(context.ReportFolder, "ScreenRecordings")
        os.makedirs(screenrecording_dir, exist_ok=True)
        context.video_path = os.path.join(os.getcwd(), screenrecording_dir, f"{name}.mp4")
        screen_size = pyautogui.size()
        fourcc = cv2.VideoWriter_fourcc(*"mp4v")
        context.video_writer = cv2.VideoWriter(context.video_path, fourcc, 20.0, (screen_size.width, screen_size.height))
        if not context.video_writer.isOpened():
            raise Exception("VideoWriter failed to open")
        context.is_recording = True
        context.recording_thread = threading.Thread(target=record_screen, args=(context,))
        context.recording_thread.start()
    except Exception as e:
        print(f"Error starting recording: {e}")


def record_screen(context):
    try:
        import pyautogui
        while getattr(context, "is_recording", False):
            img = pyautogui.screenshot()
            frame = cv2.cvtColor(np.array(img), cv2.COLOR_BGR2RGB)
            context.video_writer.write(frame)
    except Exception as e:
        print(f"Error during screen recording: {e}")


def stop_recording(context):
    try:
        if getattr(context, 'is_recording', False):
            context.is_recording = False
            if hasattr(context, 'recording_thread'):
                context.recording_thread.join()
            if hasattr(context, 'video_writer'):
                context.video_writer.release()
    except Exception as e:
        print(f"Error stopping recording: {e}")


def delete_recorded_file(context):
    try:
        if hasattr(context, 'video_path') and os.path.exists(context.video_path):
            os.remove(context.video_path)
    except Exception as e:
        print(f"Error deleting video file: {e}")

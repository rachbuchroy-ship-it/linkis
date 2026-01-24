from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager
import os

# הגדרת נתיב לשמירת נתוני המשתמש (בתוך תיקייה בפרויקט שלך)
# זה יוצר תיקייה בשם "whatsapp_data" שבה יישמר החיבור
script_dir = os.path.dirname(os.path.abspath(__file__))
user_data_path = os.path.join(script_dir, "whatsapp_session")

chrome_options = Options()
chrome_options.add_argument(f"--user-data-dir={user_data_path}")
chrome_options.add_argument("--profile-directory=Default") # שימוש בפרופיל ברירת המחדל בתוך התיקייה

# הפעלת הדפדפן
driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=chrome_options)

try:
    driver.get("https://web.whatsapp.com")
    
    print("בודק חיבור... אם זו פעם ראשונה, אנא סרוק את ה-QR.")
    
    # כאן הסקריפט ימשיך לעבוד. אם כבר התחברת בעבר, וואטסאפ פשוט ייפתח.
    input("לחץ Enter אחרי שהדף נטען במלואו כדי להדפיס את ה-DOM...")

    print(driver.page_source)

finally:
    # driver.quit() # אם תרצה שהדפדפן ייסגר בסוף
    pass
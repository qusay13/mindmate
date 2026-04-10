import requests

BASE_URL = "http://127.0.0.1:8000/api/survey/"
# قُم بنسخ التوكن الخاص بك هنا بعد تجربة تسجيل الدخول
TOKEN = "YOUR_TOKEN_HERE"

headers = {
    "Authorization": f"Bearer {TOKEN}"
}

def test_pro_survey():
    print("1. Fetching Questions...")
    res = requests.get(BASE_URL + "questions/", headers=headers)
    print(res.status_code)
    print(res.json())

    print("\n2. Submitting Answers...")
    data = {
        "responses": [
            {
                # ضع هنا رقم معرف حقيقي من مخرجات واجهة الأسئلة
                "question_id": 1, 
                "answer_value": 3.0
            }
        ]
    }

    res = requests.post(BASE_URL + "submit/", json=data, headers=headers)
    print(res.status_code)
    print(res.json())

if __name__ == "__main__":
    test_pro_survey()

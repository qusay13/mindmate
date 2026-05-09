import os
from dotenv import load_dotenv
import google.generativeai as genai
from django.conf import settings

load_dotenv()

class AIService:
    def __init__(self):
        # Fallback if not in settings yet, we added it to .env
        api_key = os.getenv('GOOGLE_API_KEY')
        if api_key:
            genai.configure(api_key=api_key)
            self.model = genai.GenerativeModel(
                model_name="gemini-flash-latest",
                system_instruction=(
                    "You are MindMate AI, a supportive and professional psychological assistant. "
                    "Your goal is to listen to the user, provide empathetic responses, and offer general mental health support. "
                    "Do not provide medical prescriptions or clinical diagnoses. "
                    "If the user expresses thoughts of self-harm or suicide, you must strongly and compassionately advise them to seek professional help immediately "
                    "and provide them with the knowledge that help is available. "
                    "Keep your responses concise, supportive, and in the language the user speaks (Arabic or English)."
                )
            )
        else:
            self.model = None

    def get_response(self, chat_history, user_message):
        if not self.model:
            return "I'm sorry, my AI brain is currently disconnected. Please contact support."

        try:
            # Format history for Gemini (alternating user/model)
            # Gemini expects 'user' and 'model' (not 'bot')
            formatted_history = []
            for msg in chat_history:
                role = "user" if msg.sender == "user" else "model"
                formatted_history.append({"role": role, "parts": [msg.content]})

            chat = self.model.start_chat(history=formatted_history)
            response = chat.send_message(user_message)
            return response.text
        except Exception as e:
            print(f"Gemini API Error: {str(e)}")
            return "I encountered an error while thinking. Could you please repeat that?"

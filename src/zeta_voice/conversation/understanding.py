from dotenv import load_dotenv

from zeta_voice.conversation.context import UnderstandingContext
from zeta_voice.conversation.flows import Response
from zeta_voice.conversation.models import Action
from zeta_voice.intent_classification.intent_classification import IntentClassification

load_dotenv()


class OpenAIUnderstandingEngine:
    """Understanding engine using OpenAI API for intent classification."""

    def __init__(self) -> None:
        self.intent_classification = IntentClassification()

    def understand(self, user_message: str, context: UnderstandingContext) -> Action:
        """Use intent classification service to understand user intent."""
        return self.intent_classification.classify_intent(user_message, context)

    def understand_question(self, user_message: str) -> Response:
        """Use intent classification service to understand user question."""
        return self.intent_classification.classify_question(user_message)

    def understand_objection(self, user_message: str) -> Response:
        """Use intent classification service to understand user objection."""
        return self.intent_classification.classify_objection(user_message)

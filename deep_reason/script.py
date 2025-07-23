import copy

import gradio as gr

from modules import chat
from modules.logging_colors import logger

params = {
    "display_name": "Deep Reason",
    "is_tab": True,
    "activate": True,
    "HEADER_1": """Below is a complex problem that requires careful analysis and deep thinking. Your task is to work through this problem step by step, thinking aloud as you explore it. Please start by introducing the problem with a phrase like, "Okay, so I need to work through..." or "Alright, let me think carefully about...". Then, explore each aspect of the problem thoroughly, considering different angles and possibilities. Express any uncertainties, questions, or complications that come up as you analyze it. Write your thoughts in full sentences, without using any markdown or bullet points, and keep the tone conversational and exploratory. Be detailed and meticulous in your analysis, ensuring that you examine all aspects of the problem from multiple perspectives. Don't rush to conclusions - take your time to really understand what's being asked and what makes it challenging.

--- PROBLEM TO ANALYZE ---""",
    "FOOTER_1": """--- PROBLEM ENDS ---

Now work through this thoroughly. Be conversational and detailed as you explore every angle of this problem, questioning your own assumptions and considering alternative approaches as you go.""",
    "MIDDLE_2": """--- ANALYTICAL CONTEXT ---

1. Use the following detailed analysis to help craft your response.
2. Never reference this analysis - treat it as internal guidance only.
3. Build upon the insights and reasoning developed below.

DETAILED REASONING:""",
    "FOOTER_2": """--- END REASONING ---""",
}

original_generate_chat_reply = chat.generate_chat_reply


def generate_chat_reply_deep_reason(text, state, regenerate=False, _continue=False, loading_message=True, for_ui=False):
    if _continue or not params["activate"]:
        for result in original_generate_chat_reply(text, state, regenerate=regenerate, _continue=_continue, loading_message=loading_message, for_ui=for_ui):
            yield result
    else:
        # Handle dict format with text and files
        files = []
        if isinstance(text, dict):
            files = text.get('files', [])
            actual_text = text.get('text', '')
        else:
            actual_text = text

        if regenerate:
            # Extract the original user message and set flag
            actual_text = state['history']['internal'][-1][0]
            regenerate_mode = True
        else:
            regenerate_mode = False

        # Initialize metadata if not present
        if 'metadata' not in state['history']:
            state['history']['metadata'] = {}

        logger.info("Deep Reason is starting Step 1. The analysis for Step 2 will be:")

        # Step 1: Create isolated state for reasoning
        step_1_state = copy.deepcopy(state)
        step_1_state["enable_web_search"] = False
        if regenerate_mode:
            step_1_state['history']['internal'] = state['history']['internal'][:-1]  # Remove last exchange
            step_1_state['history']['visible'] = state['history']['visible'][:-1]    # Remove last exchange

        step_1_text = generate_step_1_prompt(actual_text)
        step_1_input = {"text": step_1_text, "files": files} if (files and not regenerate_mode) else step_1_text

        step_1_result = ""
        previous_result = ""

        for i, result in enumerate(original_generate_chat_reply(step_1_input, step_1_state, regenerate=False, _continue=False, loading_message=loading_message, for_ui=for_ui)):
            # Show "working..." message
            yield {
                'visible': result['visible'][:-1] + [[actual_text, "*Deep Reason is working...*"]],
                'internal': result['internal'][:-1] + [[actual_text, "*Deep Reason is working...*"]],
                'metadata': result['metadata']
            }

            step_1_result = result['internal'][-1][1]

            if i == 1:
                print("\n")

            print(step_1_result[len(previous_result):], end='', flush=True)
            previous_result = step_1_result

        logger.info("Deep Reason Step 1 is complete. Starting Step 2.")

        # Step 2: Create the final prompt with reasoning context
        step_2_text = generate_step_2_prompt(actual_text, step_1_result)
        step_2_input = {"text": step_2_text, "files": files} if files else step_2_text

        if regenerate_mode:
            # Temporarily replace user message for generation
            original_msg = state['history']['internal'][-1][0]
            state['history']['internal'][-1][0] = step_2_text

            try:
                for result in original_generate_chat_reply(text, state, regenerate=True, _continue=False, loading_message=loading_message, for_ui=for_ui):
                    # Restore original message in yields
                    result['internal'][-1][0] = actual_text
                    result['visible'][-1][0] = actual_text
                    yield result
            finally:
                # Ensure original message is restored even if an exception occurs
                state['history']['internal'][-1][0] = original_msg
        else:
            # Normal new message flow
            for result in original_generate_chat_reply(step_2_input, state, regenerate=False, _continue=False, loading_message=loading_message, for_ui=for_ui):
                result['internal'][-1][0] = actual_text  # Show original text to user
                result['visible'][-1][0] = actual_text   # Show original text to user
                yield result


def setup():
    chat.generate_chat_reply = generate_chat_reply_deep_reason


def ui():
    gr.Markdown("# Deep Reason v0.4")
    activate = gr.Checkbox(value=params["activate"], label="Activate Deep Reason")
    with gr.Tab("Step 1: Thinking About the Prompt"):
        with gr.Row():
            with gr.Column():
                header_1 = gr.Textbox(value=params["HEADER_1"], lines=14, label="HEADER_1", elem_classes=["add_scrollbar"])
                footer_1 = gr.Textbox(value=params["FOOTER_1"], lines=7, label="FOOTER_1", elem_classes=["add_scrollbar"])

            with gr.Column():
                output_1 = gr.Textbox(value=generate_step_1_prompt("[Your question will go here]"), lines=27, label="Step 1 example", elem_classes=["add_scrollbar"])

    with gr.Tab("Step 2: Generating the Response"):
        with gr.Row():
            with gr.Column():
                middle_2 = gr.Textbox(value=params["MIDDLE_2"], lines=14, label="MIDDLE_2", elem_classes=["add_scrollbar"])
                footer_2 = gr.Textbox(value=params["FOOTER_2"], lines=7, label="FOOTER_2", elem_classes=["add_scrollbar"])

            with gr.Column():
                output_2 = gr.Textbox(value=generate_step_2_prompt("[Your question will go here]", "[The analysis from step 1 will go here]"), lines=27, label="Step 2 example", elem_classes=["add_scrollbar"])

    activate.change(lambda x: params.update({"activate": x}), activate, None)
    header_1.change(lambda x: params.update({"HEADER_1": x}), header_1, None).then(lambda: generate_step_1_prompt("[Your question will go here]"), None, output_1, show_progress=False)
    footer_1.change(lambda x: params.update({"FOOTER_1": x}), footer_1, None).then(lambda: generate_step_1_prompt("[Your question will go here]"), None, output_1, show_progress=False)
    middle_2.change(lambda x: params.update({"MIDDLE_2": x}), middle_2, None).then(lambda: generate_step_2_prompt("[Your question will go here]", "[The analysis from step 1 will go here]"), None, output_2, show_progress=False)
    footer_2.change(lambda x: params.update({"FOOTER_2": x}), footer_2, None).then(lambda: generate_step_2_prompt("[Your question will go here]", "[The analysis from step 1 will go here]"), None, output_2, show_progress=False)


def generate_step_1_prompt(question):
    return params["HEADER_1"].rstrip() + "\n" + question + "\n\n" + params["FOOTER_1"]


def generate_step_2_prompt(question, analysis, add_footer=True):
    result = question + "\n\n" + params["MIDDLE_2"].rstrip() + "\n\n" + analysis
    if add_footer:
        result = result + "\n\n" + params["FOOTER_2"]

    return result

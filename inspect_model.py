import sys
import tensorflow as tf

interpreter = tf.lite.Interpreter(model_path="arrhythmia (1).tflite")
interpreter.allocate_tensors()

with open("model_info.txt", "w") as f:
    f.write("--- INPUT DETAILS ---\n")
    for detail in interpreter.get_input_details():
        f.write(f"Name: {detail['name']}, Shape: {detail['shape']}, Type: {detail['dtype']}\n")

    f.write("\n--- OUTPUT DETAILS ---\n")
    for detail in interpreter.get_output_details():
        f.write(f"Name: {detail['name']}, Shape: {detail['shape']}, Type: {detail['dtype']}\n")

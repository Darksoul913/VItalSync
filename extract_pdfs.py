import PyPDF2
import os
import glob

base = r"c:\Users\shree\StudioProjects\vital_sync"

# Find the God's Plan PDF using glob
god_files = glob.glob(os.path.join(base, "God*Plan*.pdf"))
print(f"Found God's Plan files: {god_files}")

if god_files:
    reader = PyPDF2.PdfReader(god_files[0])
    text = ""
    for i, page in enumerate(reader.pages):
        t = page.extract_text()
        if t:
            text += f"\n=== PAGE {i+1} ===\n{t}"
    out_path = os.path.join(base, "gods_plan_text.txt")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(text)
    print(f"God's Plan: {len(reader.pages)} pages, {len(text)} chars -> {out_path}")

# Extract VitalSync-Overview.pdf
pdf_path2 = os.path.join(base, "VitalSync-Overview.pdf")
reader2 = PyPDF2.PdfReader(pdf_path2)
text2 = ""
for i, page in enumerate(reader2.pages):
    t = page.extract_text()
    if t:
        text2 += f"\n=== PAGE {i+1} ===\n{t}"
out_path2 = os.path.join(base, "vitalsync_text.txt")
with open(out_path2, "w", encoding="utf-8") as f:
    f.write(text2)
print(f"VitalSync Overview: {len(reader2.pages)} pages, {len(text2)} chars -> {out_path2}")

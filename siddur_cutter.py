import os
from pypdf import PdfReader, PdfWriter

def split_and_compress_siddur(input_pdf_path, output_folder, sections_map, offset):
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)
        
    print("📖 מתחיל לקרוא את קובץ הסידור המקורי...")
    
    if not os.path.exists(input_pdf_path):
        print(f"❌ שגיאה: לא מצאתי קובץ בשם '{input_pdf_path}' בתיקייה!")
        return

    reader = PdfReader(input_pdf_path)
    total_pages = len(reader.pages)
    print(f"📄 נמצאו {total_pages} עמודים בקובץ המקור.")
    
    for section_name, page_range in sections_map.items():
        writer = PdfWriter()
        
        # חישוב העמודים כולל הקיזוז
        start_page = (page_range[0] + offset) - 1  
        end_page = (page_range[1] + offset) - 1
        
        if start_page < 0 or end_page >= total_pages:
            print(f"⚠️ אזהרה: טווח העמודים עבור {section_name} חורג מגבולות הקובץ. מדלג...")
            continue
            
        print(f"✂️ חותך את: {section_name} (עמודים מודפסים {page_range[0]}-{page_range[1]})")
        
        for page_num in range(start_page, end_page + 1):
            page = reader.pages[page_num]
            writer.add_page(page)  # הוספת העמוד נשארה נקייה ובטוחה
        
        # שמירת הקובץ שנוצר
        output_filename = os.path.join(output_folder, f"{section_name}.pdf")
        with open(output_filename, "wb") as f:
            writer.write(f)
            
    print("\n🎉 הסתיים בהצלחה! כל חלקי הסידור חולקו ונשמרו בתיקייה המיועדת.")

# --- הגדרות הפרויקט ---
NAME_OF_YOUR_PDF_FILE = "siddur.pdf" 
OUTPUT_DIR = "./siddur_output_files"
OFFSET = 2  

SIDDUR_MAP = {
    "01_birchot_hashachar": (11, 11),   
    "02_shacharit_chol": (12, 95),      
    "03_mincha_chol": (96, 105),        
    "04_arvit_chol": (106, 117),        
    "05_kriat_shema_mita": (118, 123),  
    "06_kabbalat_shabbat": (128, 143),  
    "07_shacharit_shabbat": (148, 185)  
}

split_and_compress_siddur(NAME_OF_YOUR_PDF_FILE, OUTPUT_DIR, SIDDUR_MAP, OFFSET)
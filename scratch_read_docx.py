import zipfile
import xml.etree.ElementTree as ET

def extract_text_from_docx(docx_path):
    try:
        with zipfile.ZipFile(docx_path) as docx:
            xml_content = docx.read('word/document.xml')
            tree = ET.fromstring(xml_content)
            
            # Extract text from w:t elements
            namespace = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
            texts = []
            for paragraph in tree.findall('.//w:p', namespace):
                texts.append("".join([node.text for node in paragraph.findall('.//w:t', namespace) if node.text]))
            return '\n'.join(texts)
    except Exception as e:
        return f"Error: {str(e)}"

if __name__ == '__main__':
    print(extract_text_from_docx('/home/qusay/Desktop/projects/mindmate/MindMate_Backend_Roadmap(1).docx'))

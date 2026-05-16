import os
import ast

def get_class_info(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        try:
            content = f.read()
            tree = ast.parse(content)
        except Exception:
            return []

    classes = []
    for node in ast.walk(tree):
        if isinstance(node, ast.ClassDef):
            bases = []
            for base in node.bases:
                if isinstance(base, ast.Name):
                    bases.append(base.id)
                elif isinstance(base, ast.Attribute):
                    bases.append(base.attr)

            methods = []
            attributes = []
            
            for child in node.body:
                if isinstance(child, ast.FunctionDef):
                    if child.name.startswith('__') and child.name not in ['__str__', '__init__']:
                        continue
                    methods.append(child.name)
                elif isinstance(child, ast.Assign):
                    for target in child.targets:
                        if isinstance(target, ast.Name):
                            attributes.append(target.id)
                elif isinstance(child, ast.AnnAssign):
                    if isinstance(child.target, ast.Name):
                        attributes.append(child.target.id)
            
            # Determine category based on filename and class name
            category = "Other"
            if "models.py" in filepath: category = "Model"
            elif "serializers.py" in filepath: category = "Serializer"
            elif "views.py" in filepath: category = "View"
            elif "consumers.py" in filepath: category = "Consumer"
            elif "admin.py" in filepath: category = "Admin"
            elif "tests" in filepath: category = "Test"
            elif "urls.py" in filepath: category = "Skip"
            
            # Skip noise classes
            if node.name == "Meta" or node.name.endswith("Config") or node.name.endswith("Migration") or category in ["Admin", "Test", "Skip"] or "Test" in node.name:
                continue
                
            classes.append({
                "name": node.name,
                "bases": bases,
                "methods": methods,
                "attributes": attributes,
                "category": category
            })
    return classes

all_classes = []
for root, dirs, files in os.walk('.'):
    if 'venv' in root or '__pycache__' in root or 'migrations' in root or '.git' in root or 'front' in root or 'frontend' in root:
        continue
    for file in files:
        if file.endswith('.py'):
            path = os.path.join(root, file)
            all_classes.extend(get_class_info(path))

# Groupings
models = [c for c in all_classes if c['category'] == 'Model']
serializers = [c for c in all_classes if c['category'] == 'Serializer']
views = [c for c in all_classes if c['category'] == 'View']
others = [c for c in all_classes if c['category'] in ['Consumer', 'Other']]

def generate_mermaid(class_list):
    lines = ["classDiagram", "    direction LR"]
    
    # Pre-collect all class names in this specific graph to prevent dangling references 
    # if a base class doesn't exist in the current subset.
    valid_names = {c['name'] for c in class_list}
    
    for c in class_list:
        lines.append(f"    class {c['name']} {{")
        for attr in c['attributes']:
            # simple filter to avoid massive outputs
            if attr.upper() == attr and len(attr) > 2: continue # skip pure constants like GENDER_CHOICES to save space
            lines.append(f"        +{attr}")
        for method in c['methods']:
            lines.append(f"        +{method}()")
        lines.append("    }")
        
        for base in c['bases']:
            # Only link to base if the base is drawn, OR just draw the base as a stub
            clean_base = base.replace('.', '_')
            if clean_base not in valid_names:
                lines.append(f"    class {clean_base}") # Stub it
            lines.append(f"    {c['name']} --|> {clean_base}")
    return "\n".join(lines)


html_template_start = """<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MindMate - توثيق الكلاسات الشامل (Full Classes UML)</title>
    <link href="https://fonts.googleapis.com/css2?family=Tajawal:wght@400;700;800&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Tajawal', sans-serif; background-color: #f4f7f6; margin: 0; padding: 20px; color: #333; }
        header { background-color: #2c3e7a; color: white; padding: 20px; text-align: center; border-radius: 8px; margin-bottom: 20px;}
        h2 { color: #2c3e7a; border-bottom: 2px solid #eef2ff; padding-bottom: 10px; margin-top: 40px;}
        .mermaid-container { background: white; padding: 20px; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.05); width: 100%; height: 80vh; margin-bottom: 40px; border-top: 4px solid #3b5bdb; overflow: hidden; cursor: grab; }
        .mermaid-container:active { cursor: grabbing; }
        .zoom-controls { margin-bottom: 10px; }
        .zoom-controls button { background: #2c3e7a; color: white; border: none; padding: 8px 15px; margin-left: 5px; border-radius: 4px; cursor: pointer; }
        .zoom-controls button:hover { background: #3b5bdb; }
    </style>
    <script src="https://cdn.jsdelivr.net/npm/svg-pan-zoom@3.6.1/dist/svg-pan-zoom.min.js"></script>
</head>
<body>
    <header>
        <h1>MindMate — توثيق الكلاسات الشامل (Full Classes UML)</h1>
        <p>يحتوي هذا الملف على جميع كلاسات المشروع مستخرجة تلقائياً من الكود המصدري.</p>
    </header>
"""

html_template_end = """
    <script type="module">
        import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';
        mermaid.initialize({ startOnLoad: true, theme: 'default', securityLevel: 'loose', logLevel: 1, class: {useMaxWidth: false} });

        document.addEventListener('DOMContentLoaded', () => {
            const containers = document.querySelectorAll('.mermaid-diagram');
            containers.forEach(targetNode => {
                let panZoomInstance = null;
                const observer = new MutationObserver((mutationsList, observer) => {
                    const svg = targetNode.querySelector('svg');
                    if (svg && !panZoomInstance) {
                        svg.style.width = '100%'; svg.style.height = '100%'; svg.style.maxWidth = 'none';
                        panZoomInstance = svgPanZoom(svg, { zoomEnabled: true, controlIconsEnabled: false, fit: true, center: true, minZoom: 0.1, maxZoom: 20 });
                        
                        const parent = targetNode.closest('.mermaid-container').parentElement;
                        parent.querySelector('.zoom-in').addEventListener('click', () => panZoomInstance.zoomIn());
                        parent.querySelector('.zoom-out').addEventListener('click', () => panZoomInstance.zoomOut());
                        parent.querySelector('.zoom-reset').addEventListener('click', () => { panZoomInstance.resetZoom(); panZoomInstance.center(); });
                    }
                });
                observer.observe(targetNode, { childList: true, subtree: true });
            });
        });
    </script>
</body>
</html>
"""

def make_section(title, mermaid_code, idx):
    return f"""
    <div>
        <h2>{title}</h2>
        <div class="zoom-controls">
            <button class="zoom-in">تكبير (+)</button>
            <button class="zoom-out">تصغير (-)</button>
            <button class="zoom-reset">إعادة الضبط</button>
        </div>
        <div class="mermaid-container">
            <div class="mermaid mermaid-diagram" id="diagram-{idx}">
{mermaid_code}
            </div>
        </div>
    </div>
    """

# 1. Separated Diagrams
os.makedirs("outputs", exist_ok=True)
with open("outputs/mindmate_separated_diagrams.html", "w", encoding="utf-8") as f:
    f.write(html_template_start)
    f.write(make_section("1. Models & Database Layer (طبقة قواعد البيانات)", generate_mermaid(models), 1))
    f.write(make_section("2. Serializers & Data Transfer (طبقة السيرياليزر)", generate_mermaid(serializers), 2))
    f.write(make_section("3. Views & API Endpoints (طبقة الواجهات)", generate_mermaid(views), 3))
    f.write(make_section("4. Services & Consumers (الخدمات)", generate_mermaid(others), 4))
    f.write(html_template_end)

# 2. Merged Diagram
with open("outputs/mindmate_merged_diagram.html", "w", encoding="utf-8") as f:
    f.write(html_template_start)
    f.write(make_section("المخطط العملاق لجميع كلاسات المشروع (Merged All Classes)", generate_mermaid(all_classes), 1))
    f.write(html_template_end)

print("✅ Successfully generated mindmate_separated_diagrams.html")
print("✅ Successfully generated mindmate_merged_diagram.html")

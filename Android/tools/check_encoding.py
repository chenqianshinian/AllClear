import sys, io, os
sys.stdout.reconfigure(encoding='utf-8')
base = r'E:/AllClear水印天敌/AllClear/android/app/src/main/java/com/wuyong/allclear'
for root, dirs, files in os.walk(base):
    for f in files:
        if not f.endswith('.kt'):
            continue
        p = os.path.join(root, f)
        raw = open(p, 'rb').read()
        status = []
        for enc in ('utf-8', 'utf-8-sig'):
            try:
                s = raw.decode(enc)
                status.append((enc, '未登录' in s or '水印' in s))
            except Exception as e:
                status.append((enc, 'FAIL'))
        print(f, len(raw), status)

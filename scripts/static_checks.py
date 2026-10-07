#!/usr/bin/env python3
from pathlib import Path
import json, re, sys
root=Path(__file__).resolve().parents[1]
files={p: p.read_text(errors='ignore') for p in root.rglob('*') if p.is_file() and p.suffix in {'.swift','.json','.plist'} }
all_text='\n'.join(files.values())
shelf_view = files.get(root / 'Sources/OpsNotchApp/ShelfView.swift', '')
design_system_required = [
    root / 'Sources/OpsNotchApp/DesignSystem/OpsSpacing.swift',
    root / 'Sources/OpsNotchApp/DesignSystem/OpsRadius.swift',
    root / 'Sources/OpsNotchApp/DesignSystem/OpsTypography.swift',
    root / 'Sources/OpsNotchApp/DesignSystem/OpsControlMetrics.swift',
    root / 'Sources/OpsNotchApp/DesignSystem/OpsSurface.swift',
    root / 'Sources/OpsNotchApp/DesignSystem/OpsMotion.swift',
    root / 'Sources/OpsNotchApp/DesignSystem/OpsVisualState.swift',
    root / 'Sources/OpsNotchApp/DesignSystem/OpsIconButton.swift',
]
new_ui_text = '\n'.join(
    text for path, text in files.items()
    if '/Sources/OpsNotchApp/DesignSystem/' in path.as_posix()
    or '/Sources/OpsNotchApp/Shelf/' in path.as_posix()
)
checks={
 'no Tauri': 'tauri' not in all_text.lower(),
 'no React': 'react' not in all_text.lower(),
 'no Vite': 'vite' not in all_text.lower(),
 'native dragging destination': 'registerForDraggedTypes([.fileURL, .URL, .string])' in all_text,
 'clipboard changeCount': 'changeCount' in all_text,
 'multi display': 'NSScreen.screens' in all_text and 'didChangeScreenParametersNotification' in all_text,
 'native status item': 'NSStatusBar.system.statusItem' in all_text,
 'quick look': 'QLPreviewPanel' in all_text,
 'login item': 'SMAppService.mainApp' in all_text,
 'accessory app': 'setActivationPolicy(.accessory)' in all_text,
 'safe action guard': 'SafeActionValidator.validate' in all_text,
 'no global shortcut plugin': 'global-shortcut' not in all_text.lower(),
 '3.0 design system files': all(path.is_file() for path in design_system_required),
 'Shelf uses design tokens': all(token in shelf_view for token in ('OpsSpacing.', 'OpsRadius.', 'OpsTypography.', 'OpsControlMetrics.')),
 'no raw icon tap gestures in new UI': re.search(r'Image\s*\([^)]*\)[\s\S]{0,220}\.onTapGesture', new_ui_text) is None,
}
for name, ok in checks.items(): print(('PASS' if ok else 'FAIL'), name)
if not all(checks.values()): sys.exit(1)

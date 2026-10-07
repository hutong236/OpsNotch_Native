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
phase2_required = [
    root / 'Sources/OpsNotchApp/Shelf/ShelfPresentationItem.swift',
    root / 'Sources/OpsNotchApp/Shelf/ShelfPresentationAdapter.swift',
    root / 'Sources/OpsNotchApp/Shelf/ShelfCommandBar.swift',
    root / 'Sources/OpsNotchApp/Shelf/ShelfSectionView.swift',
    root / 'Sources/OpsNotchApp/Shelf/ShelfRow.swift',
    root / 'Sources/OpsNotchApp/Shelf/ShelfEmptyState.swift',
]
phase6_settings_required = [
    root / 'Sources/OpsNotchApp/Settings/SettingsRootView.swift',
    root / 'Sources/OpsNotchApp/Settings/SettingsComponents.swift',
    root / 'Sources/OpsNotchApp/Settings/GeneralSettingsView.swift',
    root / 'Sources/OpsNotchApp/Settings/ShelfSettingsView.swift',
    root / 'Sources/OpsNotchApp/Settings/ClipboardSettingsView.swift',
    root / 'Sources/OpsNotchApp/Settings/FinderSettingsView.swift',
    root / 'Sources/OpsNotchApp/Settings/WorkspaceSettingsPane.swift',
    root / 'Sources/OpsNotchApp/Settings/ShortcutSettingsView.swift',
    root / 'Sources/OpsNotchApp/Settings/AdvancedSettingsView.swift',
]
settings_controller = files.get(root / 'Sources/OpsNotchApp/SettingsWindowController.swift', '')
legacy_row_types = (
    'private struct DesktopQuickShelfRowView',
    'private struct FinderQuickShelfRowView',
    'private struct LocalQuickShelfRowView',
    'struct ShelfRowView',
)
new_ui_text = '\n'.join(
    text for path, text in files.items()
    if '/Sources/OpsNotchApp/DesignSystem/' in path.as_posix()
    or '/Sources/OpsNotchApp/Shelf/' in path.as_posix()
)
presentation_text = '\n'.join(
    text for path, text in files.items()
    if path == root / 'Sources/OpsNotchApp/ShelfWindowController.swift'
    or '/Sources/OpsNotchApp/Shelf/Presentation/' in path.as_posix()
)
localized_ui_paths = [
    root / 'Sources/OpsNotchApp/ShelfView.swift',
    root / 'Sources/OpsNotchApp/StatusBarController.swift',
]
localized_ui_paths += sorted((root / 'Sources/OpsNotchApp/Shelf').rglob('*.swift'))
localized_ui_paths += sorted((root / 'Sources/OpsNotchApp/Settings').rglob('*.swift'))
localized_ui_text = '\n'.join(
    path.read_text(errors='ignore') for path in localized_ui_paths if path.is_file()
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
 '3.0 unified shelf component files': all(path.is_file() for path in phase2_required),
 'legacy Quick Shelf row types removed': all(name not in shelf_view for name in legacy_row_types),
 'presentation uses motion tokens': re.search(r'context\.duration\s*=\s*[0-9]', presentation_text) is None,
 '3.0 settings pages exist': all(path.is_file() for path in phase6_settings_required),
 'settings controller uses sidebar root': 'SettingsRootView(' in settings_controller,
 'legacy monolithic SettingsView removed': 'struct SettingsView: View' not in settings_controller,
 '3.0 UI uses centralized localization': re.search(r'language\s*==\s*\.zhCN\s*\?', localized_ui_text) is None,
}
for name, ok in checks.items(): print(('PASS' if ok else 'FAIL'), name)
if not all(checks.values()): sys.exit(1)

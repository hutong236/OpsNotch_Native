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
status_bar_controller = files.get(root / 'Sources/OpsNotchApp/StatusBarController.swift', '')
shelf_window_controller = files.get(root / 'Sources/OpsNotchApp/ShelfWindowController.swift', '')
ops_surface = files.get(root / 'Sources/OpsNotchApp/DesignSystem/OpsSurface.swift', '')
settings_components = files.get(root / 'Sources/OpsNotchApp/Settings/SettingsComponents.swift', '')
inspector_ui_text = '\n'.join(
    text for path, text in files.items()
    if '/Sources/OpsNotchApp/Shelf/Inspector/' in path.as_posix()
)
embedded_settings_ui_text = '\n'.join(
    files.get(path, '') for path in (
        root / 'Sources/OpsNotchApp/FinderRevealSettingsView.swift',
        root / 'Sources/OpsNotchApp/InputMethodSettingsView.swift',
    )
)
legacy_phase7_ui_paths = [
    root / 'Sources/OpsNotchApp/FinderQuickLauncherWindowController.swift',
    root / 'Sources/OpsNotchApp/WorkspaceSettingsView.swift',
    root / 'Sources/OpsNotchApp/WorkspaceQuickPanel.swift',
    root / 'Sources/OpsNotchApp/Services/WorkspaceService.swift',
    root / 'Sources/OpsNotchApp/Services/WorkspaceShortcutManager.swift',
]
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
drop_success_feedback = shelf_window_controller.split('private struct DropSuccessFeedbackView', 1)[1].split('final class ShelfPanel', 1)[0] if 'private struct DropSuccessFeedbackView' in shelf_window_controller else ''
migrated_ui_text = '\n'.join(
    text for path, text in files.items()
    if path == root / 'Sources/OpsNotchApp/ShelfView.swift'
    or path == root / 'Sources/OpsNotchApp/ShelfWindowController.swift'
    or path == root / 'Sources/OpsNotchApp/StatusBarController.swift'
    or '/Sources/OpsNotchApp/Shelf/' in path.as_posix()
    or '/Sources/OpsNotchApp/Settings/' in path.as_posix()
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
 '3.0 migrated UI has no inline language ternaries': re.search(r'language\s*==\s*\.zhCN\s*\?', migrated_ui_text) is None,
 'Shelf shell has no raw point-size fonts': re.search(r'\.font\(\.system\(size\s*:', shelf_view) is None,
 'Shelf shell has no numeric RoundedRectangle radii': re.search(r'RoundedRectangle\(cornerRadius\s*:\s*[0-9]', shelf_view) is None,
 'status menu exposes Keep Shelf Open': 'toggleKeepShelfOpen' in status_bar_controller and 'keepShelfOpen' in status_bar_controller,
 'status menu stays a concise control center': '#selector(newText)' not in status_bar_controller and 'versionItem' not in status_bar_controller,
 'legacy Phase 7 standalone UI paths removed': all(not path.exists() for path in legacy_phase7_ui_paths),
 'legacy filter-chip views stay removed': all(name not in migrated_ui_text for name in ('QuickShelfFilterBar', 'QuickShelfFilterChip', 'FilterChipView')),
 'duplicate relative-time helpers stay removed': 'RelativeTime' not in migrated_ui_text and 'relativeTime(' not in migrated_ui_text,
 'legacy preview pane stays removed': 'PreviewPane' not in migrated_ui_text and 'LegacyPreview' not in migrated_ui_text,
 'peek and confirmation remain distinct': re.search(r'func showPeek\(on screen: NSScreen\)\s*\{\s*show\(\.peek, on: screen\)\s*\}', shelf_window_controller) is not None,
 'drop success uses confirmation presentation state': re.search(r'private func showAcceptedDropFeedback\(\)\s*\{[\s\S]{0,320}show\(\.confirmation,\s*on:\s*screen\)', shelf_window_controller) is not None,
 'drop success feedback has no raw point-size fonts': re.search(r'\.font\(\.system\(size\s*:', drop_success_feedback) is None,
 'drop success feedback has no numeric RoundedRectangle radii': re.search(r'RoundedRectangle\(cornerRadius\s*:\s*[0-9]', drop_success_feedback) is None,
 'Shelf surfaces expose increased-contrast metrics': all(name in ops_surface for name in ('panelStrokeOpacity', 'focusStrokeOpacity', 'selectedOpacity', 'dropTargetStrokeOpacity')),
 'Inspector uses semantic divider surface': 'Divider().opacity(' not in inspector_ui_text,
 'Inspector preview size uses control metrics': re.search(r'\.frame\(width:\s*[0-9]+,\s*height:\s*[0-9]+\)', inspector_ui_text) is None,
 'Settings card uses semantic surface token': '.quaternary.opacity(' not in settings_components and 'OpsSurface.settingsCard' in settings_components,
 'embedded Settings use design typography': re.search(r'\.font\(\.system\(size\s*:', embedded_settings_ui_text) is None,
 'embedded Settings use semantic radii': re.search(r'RoundedRectangle\(cornerRadius\s*:\s*[0-9]', embedded_settings_ui_text) is None,
 'embedded Settings use semantic control widths': re.search(r'\.frame\(width:\s*[0-9]+', embedded_settings_ui_text) is None,
 'Shelf row keeps selection and focus as independent states': 'OpsRowVisualState' in new_ui_text and 'selected:' in files.get(root / 'Sources/OpsNotchApp/Shelf/ShelfEntryRow.swift', '') and 'focused:' in files.get(root / 'Sources/OpsNotchApp/Shelf/ShelfEntryRow.swift', ''),
}
for name, ok in checks.items(): print(('PASS' if ok else 'FAIL'), name)
if not all(checks.values()): sys.exit(1)

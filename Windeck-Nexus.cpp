// WinDeck-Nexus.cpp - The Ultimate Edition (v3.2 - Corrected & Improved)
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#include <XInput.h>
#include <string>
#include <thread>
#include <vector>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <regex>
#include <wrl.h>
#include <WebView2.h>

#pragma comment(lib, "user32.lib")
#pragma comment(lib, "shellapi.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib, "XInput.lib")
#pragma comment(lib, "advapi32.lib")

struct Game { std::wstring name, path, appId; };
HWND g_hWnd = nullptr, g_guideshWnd = nullptr;
Microsoft::WRL::ComPtr<ICoreWebView2Controller> g_webviewController;
Microsoft::WRL::ComPtr<ICoreWebView2> g_webview;
bool g_isFrontendVisible = false, g_isAppRunning = true;
std::vector<Game> g_gameLibrary;

#define WM_APP_TRAY_MSG (WM_APP + 1)
#define TRAY_ICON_ID 1
#define ID_MENU_SHOW 1001
#define ID_MENU_CONFIG 1002
#define ID_MENU_EXIT 1003
NOTIFYICONDATAW g_nid = {};

LRESULT CALLBACK WndProc(HWND, UINT, WPARAM, LPARAM);
LRESULT CALLBACK GuidesWndProc(HWND, UINT, WPARAM, LPARAM);
void CreateTrayIcon(), ShowContextMenu(HWND), ToggleFrontendVisibility(), CreateGuidesWindow(HINSTANCE);
void ControllerInputThread(), ScanForGames(), FindSteamGames(), FindRegistryGames();
void SendKey(WORD vkey);
std::wstring GetExecutablePath(), GetSteamInstallPath(), FindExecutableInDir(const std::wstring& dirPath);

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
    ScanForGames();
    WNDCLASSEXW wcex = {};
    wcex.cbSize = sizeof(WNDCLASSEXW);
    wcex.lpfnWndProc = WndProc;
    wcex.hInstance = hInstance;
    wcex.hIcon = LoadIcon(hInstance, L"IDI_ICON1");
    wcex.lpszClassName = L"WinDeckNexusClass";
    RegisterClassExW(&wcex);
    int screenWidth = GetSystemMetrics(SM_CXSCREEN), screenHeight = GetSystemMetrics(SM_CYSCREEN);
    g_hWnd = CreateWindowExW(0, L"WinDeckNexusClass", L"WinDeck Nexus", WS_POPUP, 0, 0, screenWidth, screenHeight, nullptr, nullptr, hInstance, nullptr);
    if (!g_hWnd) return 1;
    CreateTrayIcon();
    ShowWindow(g_hWnd, SW_HIDE);
    UpdateWindow(g_hWnd);
    std::thread(ControllerInputThread).detach();
    CreateCoreWebView2EnvironmentWithOptions(nullptr, nullptr, nullptr,
        Microsoft::WRL::Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
            [](HRESULT result, ICoreWebView2Environment* env) -> HRESULT {
                env->CreateCoreWebView2Controller(g_hWnd, Microsoft::WRL::Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
                    [](HRESULT result, ICoreWebView2Controller* controller) -> HRESULT {
                        g_webviewController = controller;
                        g_webviewController->get_CoreWebView2(&g_webview);
                        Microsoft::WRL::ComPtr<ICoreWebView2Settings> settings;
                        g_webview->get_Settings(&settings);
                        settings->put_IsScriptEnabled(TRUE);
                        settings->put_AreDefaultContextMenusEnabled(FALSE);
                        settings->put_IsZoomControlEnabled(FALSE);
                        RECT bounds; GetClientRect(g_hWnd, &bounds); g_webviewController->put_Bounds(bounds);
                        g_webview->Navigate((GetExecutablePath() + L"\\ui\\index.html").c_str());
                        EventRegistrationToken token;
                        g_webview->add_NavigationCompleted(Microsoft::WRL::Callback<ICoreWebView2NavigationCompletedEventHandler>(
                            [](ICoreWebView2* webview, ICoreWebView2NavigationCompletedEventArgs* args) -> HRESULT {
                                std::wstring json = L"[";
                                for (const auto& game : g_gameLibrary) {
                                    std::wstring safe_path = game.path;
                                    std::wregex backslash(L"\\\\");
                                    safe_path = std::regex_replace(safe_path, backslash, L"\\\\");
                                    json += L"{\"name\":\"" + game.name + L"\",\"path\":\"" + safe_path + L"\",\"appId\":\"" + game.appId + L"\"},";
                                }
                                if (!g_gameLibrary.empty()) json.pop_back();
                                json += L"]";
                                webview->PostWebMessageAsJson(json.c_str());
                                return S_OK;
                            }).Get(), &token);
                        g_webview->add_WebMessageReceived(Microsoft::WRL::Callback<ICoreWebView2WebMessageReceivedEventHandler>(
                            [](ICoreWebView2* webview, auto args) -> HRESULT {
                                // Game launch logic would go here
                                return S_OK;
                            }).Get(), &token);
                        return S_OK;
                    }).Get());
                return S_OK;
            }).Get());
    MSG msg;
    while (GetMessage(&msg, nullptr, 0, 0)) { TranslateMessage(&msg); DispatchMessage(&msg); }
    Shell_NotifyIconW(NIM_DELETE, &g_nid);
    return (int)msg.wParam;
}
LRESULT CALLBACK WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam) {
    switch (message) {
    case WM_APP_TRAY_MSG: if (lParam == WM_LBUTTONUP) ToggleFrontendVisibility(); else if (lParam == WM_RBUTTONUP) ShowContextMenu(hWnd); break;
    case WM_COMMAND: switch (LOWORD(wParam)) { case ID_MENU_SHOW: ToggleFrontendVisibility(); break; case ID_MENU_CONFIG: CreateGuidesWindow(GetModuleHandle(NULL)); break; case ID_MENU_EXIT: g_isAppRunning = false; DestroyWindow(hWnd); break; } break;
    case WM_DESTROY: PostQuitMessage(0); break;
    default: return DefWindowProcW(hWnd, message, wParam, lParam);
    }
    return 0;
}
void ToggleFrontendVisibility() { g_isFrontendVisible = !g_isFrontendVisible; ShowWindow(g_hWnd, g_isFrontendVisible ? SW_MAXIMIZE : SW_HIDE); if(g_isFrontendVisible) SetForegroundWindow(g_hWnd); }
void SendKey(WORD vkey) { INPUT input = {}; input.type = INPUT_KEYBOARD; input.ki = { vkey, 0, 0, 0, 0 }; SendInput(1, &input, sizeof(INPUT)); input.ki.dwFlags = KEYEVENTF_KEYUP; SendInput(1, &input, sizeof(INPUT)); }
void ControllerInputThread() {
    XINPUT_STATE prevState = {};
    while (g_isAppRunning) {
        if (!g_isFrontendVisible) {
            XINPUT_STATE state = {};
            if (XInputGetState(0, &state) == ERROR_SUCCESS) {
                auto is_pressed_once = [&](WORD button) { return (state.Gamepad.wButtons & button) && !(prevState.Gamepad.wButtons & button); };
                if ((state.Gamepad.wButtons & XINPUT_GAMEPAD_LEFT_THUMB) && (state.Gamepad.wButtons & XINPUT_GAMEPAD_RIGHT_THUMB) && !((prevState.Gamepad.wButtons & XINPUT_GAMEPAD_LEFT_THUMB) && (prevState.Gamepad.wButtons & XINPUT_GAMEPAD_RIGHT_THUMB))) { PostMessage(g_hWnd, WM_COMMAND, ID_MENU_SHOW, 0); }
                if ((state.Gamepad.wButtons & XINPUT_GAMEPAD_START) && is_pressed_once(XINPUT_GAMEPAD_X)) { HWND osk = FindWindowW(L"OSKMainClass", NULL); if (!osk) ShellExecute(NULL, L"open", L"osk.exe", NULL, NULL, SW_SHOWNORMAL); else PostMessage(osk, WM_CLOSE, 0, 0); }
                if(is_pressed_once(XINPUT_GAMEPAD_A)) SendKey(VK_RETURN);
                if(is_pressed_once(XINPUT_GAMEPAD_B)) SendKey(VK_ESCAPE);
                if(is_pressed_once(XINPUT_GAMEPAD_START)) SendKey(VK_LWIN);
                float RY = state.Gamepad.sThumbRY; if (abs(RY) > XINPUT_GAMEPAD_RIGHT_THUMB_DEADZONE) { INPUT scrollInput = {}; scrollInput.type = INPUT_MOUSE; scrollInput.mi = {0,0, static_cast<DWORD>((LONG)(RY / 256)), MOUSEEVENTF_WHEEL, 0, 0}; SendInput(1, &scrollInput, sizeof(INPUT)); }
                float LX = state.Gamepad.sThumbLX, LY = state.Gamepad.sThumbLY; if (sqrt(LX * LX + LY * LY) > XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE) { INPUT moveInput = {}; moveInput.type = INPUT_MOUSE; moveInput.mi = {(LONG)((LX/32767.0f)*15.0f), (LONG)((-LY/32767.0f)*15.0f), 0, MOUSEEVENTF_MOVE, 0, 0}; SendInput(1, &moveInput, sizeof(INPUT)); }
                prevState = state;
            }
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(16));
    }
}
void ScanForGames() { FindSteamGames(); FindRegistryGames(); }
std::wstring GetSteamInstallPath() { HKEY hKey; if (RegOpenKeyExW(HKEY_LOCAL_MACHINE, L"SOFTWARE\\Valve\\Steam", 0, KEY_READ | KEY_WOW64_32KEY, &hKey) == ERROR_SUCCESS) { wchar_t buffer[MAX_PATH]; DWORD bufferSize = sizeof(buffer); if (RegQueryValueExW(hKey, L"InstallPath", nullptr, nullptr, (LPBYTE)buffer, &bufferSize) == ERROR_SUCCESS) { RegCloseKey(hKey); return std::wstring(buffer); } RegCloseKey(hKey); } return L""; }
void FindSteamGames() { std::wstring steamPath = GetSteamInstallPath(); if (steamPath.empty()) return; std::vector<std::wstring> libraryPaths; libraryPaths.push_back(steamPath); std::wifstream libraryFile(steamPath + L"\\steamapps\\libraryfolders.vdf"); if (libraryFile.is_open()) { std::wstringstream wss; wss << libraryFile.rdbuf(); std::wstring wfileContents = wss.str(); std::wregex pathRegex(L"\"path\"\\s+\"(.+?)\""); auto matches_begin = std::wsregex_iterator(wfileContents.begin(), wfileContents.end(), pathRegex); for (auto i = matches_begin; i != std::wsregex_iterator(); ++i) { std::wstring libPath = (*i)[1].str(); libPath = std::regex_replace(libPath, std::wregex(L"\\\\\\\\"), L"\\"); libraryPaths.push_back(libPath); } } for (const auto& libPath : libraryPaths) { std::wstring steamappsPath = libPath + L"\\steamapps"; if (!std::filesystem::exists(steamappsPath)) continue; for (const auto& entry : std::filesystem::directory_iterator(steamappsPath)) { if (entry.path().filename().wstring().rfind(L"appmanifest_", 0) == 0) { std::wifstream manifestFile(entry.path()); if(manifestFile.is_open()) { std::wstringstream wss; wss << manifestFile.rdbuf(); std::wstring wManifestContents = wss.str(); std::wsmatch appid_match, name_match, installdir_match; if (std::regex_search(wManifestContents, appid_match, std::wregex(L"\"appid\"\\s+\"(\\d+)\"")) && std::regex_search(wManifestContents, name_match, std::wregex(L"\"name\"\\s+\"(.+?)\"")) && std::regex_search(wManifestContents, installdir_match, std::wregex(L"\"installdir\"\\s+\"(.+?)\""))) { std::wstring gameDir = steamappsPath + L"\\common\\" + installdir_match[1].str(); std::wstring exePath = FindExecutableInDir(gameDir); if (!exePath.empty()) { g_gameLibrary.push_back({name_match[1].str(), exePath, appid_match[1].str()}); } } } } } } }
void FindRegistryGames() { const wchar_t* regKey = L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall"; HKEY hKey; if (RegOpenKeyExW(HKEY_LOCAL_MACHINE, regKey, 0, KEY_READ | KEY_WOW64_64KEY, &hKey) != ERROR_SUCCESS) return; wchar_t subKeyName[255]; DWORD subKeySize = 255; for (DWORD i = 0; RegEnumKeyExW(hKey, i, subKeyName, &subKeySize, NULL, NULL, NULL, NULL) == ERROR_SUCCESS; i++, subKeySize = 255) { HKEY hSubKey; if (RegOpenKeyExW(hKey, subKeyName, 0, KEY_READ, &hSubKey) == ERROR_SUCCESS) { wchar_t displayName[255] = {0}, installLocation[MAX_PATH] = {0}, publisher[255] = {0}; DWORD nameSize = sizeof(displayName), locSize = sizeof(installLocation), pubSize = sizeof(publisher); if (RegQueryValueExW(hSubKey, L"DisplayName", NULL, NULL, (LPBYTE)displayName, &nameSize) == ERROR_SUCCESS && RegQueryValueExW(hSubKey, L"InstallLocation", NULL, NULL, (LPBYTE)installLocation, &locSize) == ERROR_SUCCESS) { RegQueryValueExW(hSubKey, L"Publisher", NULL, NULL, (LPBYTE)publisher, &pubSize); std::wstring publisherStr(publisher), nameStr(displayName); if (!nameStr.empty() && locSize > 0 && publisherStr.find(L"Microsoft") == std::wstring::npos && nameStr.find(L"Update") == std::wstring::npos) { std::wstring exePath = FindExecutableInDir(installLocation); if(!exePath.empty()) { g_gameLibrary.push_back({nameStr, exePath, L""}); } } } RegCloseKey(hSubKey); } } RegCloseKey(hKey); }
std::wstring FindExecutableInDir(const std::wstring& dirPath) { if (!std::filesystem::exists(dirPath)) return L""; for (const auto& entry : std::filesystem::recursive_directory_iterator(dirPath)) { if (entry.is_regular_file() && entry.path().extension() == L".exe") { return entry.path().wstring(); } } return L""; }
void CreateTrayIcon() { g_nid.cbSize = sizeof(NOTIFYICONDATAW); g_nid.hWnd = g_hWnd; g_nid.uID = TRAY_ICON_ID; g_nid.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP; g_nid.uCallbackMessage = WM_APP_TRAY_MSG; g_nid.hIcon = LoadIcon(GetModuleHandle(NULL), L"IDI_ICON1"); wcscpy_s(g_nid.szTip, L"WinDeck Nexus"); Shell_NotifyIconW(NIM_ADD, &g_nid); }
void ShowContextMenu(HWND hwnd) { POINT curPoint; GetCursorPos(&curPoint); HMENU hMenu = CreatePopupMenu(); InsertMenuW(hMenu, 0, MF_BYPOSITION | MF_STRING, ID_MENU_SHOW, L"Show/Hide Frontend"); InsertMenuW(hMenu, 1, MF_BYPOSITION | MF_STRING, ID_MENU_CONFIG, L"Configuration Hub"); InsertMenuW(hMenu, 2, MF_BYPOSITION | MF_STRING, ID_MENU_EXIT, L"Exit"); SetForegroundWindow(hwnd); TrackPopupMenu(hMenu, TPM_RIGHTBUTTON, curPoint.x, curPoint.y, 0, hwnd, NULL); }
void CreateGuidesWindow(HINSTANCE hInstance) { if (g_guideshWnd) { ShowWindow(g_guideshWnd, SW_SHOW); SetForegroundWindow(g_guideshWnd); return; } WNDCLASSEXW wcex = {}; wcex.cbSize = sizeof(WNDCLASSEXW); wcex.lpfnWndProc = GuidesWndProc; wcex.hInstance = hInstance; wcex.hIcon = LoadIcon(hInstance, L"IDI_ICON1"); wcex.lpszClassName = L"WinDeckGuidesClass"; RegisterClassExW(&wcex); g_guideshWnd = CreateWindowW(L"WinDeckGuidesClass", L"WinDeck Nexus Guides", WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, 1024, 768, nullptr, nullptr, hInstance, nullptr); ShowWindow(g_guideshWnd, SW_SHOW); UpdateWindow(g_guideshWnd); CreateCoreWebView2EnvironmentWithOptions(nullptr, nullptr, nullptr, Microsoft::WRL::Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>([](HRESULT result, ICoreWebView2Environment* env) -> HRESULT { env->CreateCoreWebView2Controller(g_guideshWnd, Microsoft::WRL::Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>([](HRESULT result, ICoreWebView2Controller* controller) -> HRESULT { Microsoft::WRL::ComPtr<ICoreWebView2> webview; controller->get_CoreWebView2(&webview); RECT bounds; GetClientRect(g_guideshWnd, &bounds); controller->put_Bounds(bounds); webview->Navigate((GetExecutablePath() + L"\\ui\\guides.html").c_str()); return S_OK; }).Get()); return S_OK; }).Get()); }
LRESULT CALLBACK GuidesWndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam) { if (message == WM_DESTROY) { g_guideshWnd = nullptr; return 0; } return DefWindowProcW(hWnd, message, wParam, lParam); }
std::wstring GetExecutablePath() { wchar_t path[MAX_PATH] = { 0 }; GetModuleFileNameW(NULL, path, MAX_PATH); *wcsrchr(path, L'\\') = L'\0'; return std::wstring(path); }
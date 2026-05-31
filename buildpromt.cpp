#include <iostream>
#include <string>
#include <array>
#include <cstdio>
#include <sstream>
#include <fstream>
#include <regex>

#ifdef _WIN32
#include <windows.h>
#define USE_MOCK_MODEL 1
#else
#define USE_MOCK_MODEL 0
#endif

struct EEGAdviceInput {
    std::string state = "normal";
    std::string direction = "";

    int focus = 0;
    int fatigue = 0;
    int relax = 0;
    int load = 0;

    int quality = 0;
    float confidence = 0.0f;

    int focusTrend = 0;    // 1 up, 0 none, -1 down
    int fatigueTrend = 0;
    int relaxTrend = 0;
    int loadTrend = 0;
};

std::string trendText(int trend) {
    if (trend == 1) return "up";
    if (trend == -1) return "down";
    return "none";
}

std::string levelText(int value) {
    if (value >= 70) return "high";
    if (value >= 40) return "medium";
    return "low";
}

std::string buildDirection(const EEGAdviceInput& input) {
    if (!input.direction.empty()) {
        return input.direction;
    }

    if (input.quality < 50) {
        return "check_signal_or_adjust_device";
    }

    if (input.fatigue >= 70) {
        return "short_rest";
    }

    if (input.load >= 75) {
        return "slow_breathing_or_relax";
    }

    if (input.focus >= 70 && input.fatigue < 50) {
        return "keep_current_pace";
    }

    if (input.relax >= 65) {
        return "low_pressure_activity";
    }

    return "keep_current_pace";
}

std::string buildPrompt(const EEGAdviceInput& input) {
    std::string direction = buildDirection(input);

    return
        "<|im_start|>system\n"
        "你是脑电健康建议生成器。\n"
        "根据脑状态指标生成一句中文建议。\n\n"
        "严格规则：\n"
        "只输出一句建议。\n"
        "不要解释脑电指标。\n"
        "不要提到Alpha、Beta、Theta。\n"
        "不要诊断疾病。\n"
        "不要分点。\n"
        "不要输出英文。\n"
        "不要输出JSON。\n"
        "语气专业、温和、自然。\n"
        "不超过22字。\n"
        "建议必须符合允许方向。\n\n"
        "状态标签说明：\n"
        "focus/fatigue/relax/load 数值范围为0到100。\n"
        "trend: 1=上升，0=无明显变化，-1=下降。\n\n"
        "当前脑状态：\n"
        "state=" + input.state + "\n"
        "focus=" + std::to_string(input.focus) + " (" + levelText(input.focus) + ")\n"
        "fatigue=" + std::to_string(input.fatigue) + " (" + levelText(input.fatigue) + ")\n"
        "relax=" + std::to_string(input.relax) + " (" + levelText(input.relax) + ")\n"
        "load=" + std::to_string(input.load) + " (" + levelText(input.load) + ")\n"
        "quality=" + std::to_string(input.quality) + "\n"
        "confidence=" + std::to_string(input.confidence) + "\n"
        "focusTrend=" + trendText(input.focusTrend) + "\n"
        "fatigueTrend=" + trendText(input.fatigueTrend) + "\n"
        "relaxTrend=" + trendText(input.relaxTrend) + "\n"
        "loadTrend=" + trendText(input.loadTrend) + "\n"
        "allowed_direction=" + direction + "\n"
        "<|im_end|>\n"
        "<|im_start|>user\n"
        "请根据当前脑状态生成一句建议。\n"
        "<|im_end|>\n"
        "<|im_start|>assistant\n"
        "建议：";
}

std::string trim(const std::string& s) {
    size_t start = 0;
    while (start < s.size() &&
           (s[start] == ' ' || s[start] == '\n' || s[start] == '\r' || s[start] == '\t')) {
        start++;
    }

    size_t end = s.size();
    while (end > start &&
           (s[end - 1] == ' ' || s[end - 1] == '\n' || s[end - 1] == '\r' || s[end - 1] == '\t')) {
        end--;
    }

    return s.substr(start, end - start);
}

bool containsChinese(const std::string& s) {
    for (unsigned char c : s) {
        if (c >= 0xE4 && c <= 0xE9) {
            return true;
        }
    }
    return false;
}

std::string fallbackAdvice(const EEGAdviceInput& input) {
    if (input.quality < 50) {
        return "建议：请调整设备后重新检测。";
    }

    if (input.fatigue >= 70) {
        return "建议：闭眼休息片刻再继续。";
    }

    if (input.load >= 75) {
        return "建议：放慢呼吸，短暂放松。";
    }

    if (input.focus >= 70 && input.fatigue < 50) {
        return "建议：保持节奏，继续当前任务。";
    }

    if (input.relax >= 65) {
        return "建议：保持放松，适合低压力活动。";
    }

    return "建议：保持当前节奏。";
}

std::string cleanOutput(std::string text, const EEGAdviceInput& input) {
    const std::string eos = "[end of text]";
    size_t pos = text.find(eos);
    if (pos != std::string::npos) {
        text = text.substr(0, pos);
    }

    text = trim(text);

    std::string bestLine;
    size_t end = text.size();

    while (end > 0) {
        size_t start = text.rfind('\n', end - 1);

        std::string line;
        if (start == std::string::npos) {
            line = text.substr(0, end);
        } else {
            line = text.substr(start + 1, end - start - 1);
        }

        line = trim(line);

        if (!line.empty()
            && line != "assistant"
            && line != "user"
            && containsChinese(line)
            && line.find("RKNN") == std::string::npos
            && line.find("ggml") == std::string::npos
            && line.find("model") == std::string::npos
            && line.find("pipeline") == std::string::npos
            && line.find("n_gpu_layers") == std::string::npos
            && line.find("loaded_nodes") == std::string::npos) {
            bestLine = line;
            break;
        }

        if (start == std::string::npos) {
            break;
        }

        end = start;
    }

    if (bestLine.empty()) {
        bestLine = fallbackAdvice(input);
    }

    if (bestLine.find("建议：") == std::string::npos) {
        bestLine = "建议：" + bestLine;
    }

    return bestLine;
}

std::string escapeJson(const std::string& input) {
    std::string output;

    for (char c : input) {
        switch (c) {
            case '\"': output += "\\\""; break;
            case '\\': output += "\\\\"; break;
            case '\n': output += "\\n"; break;
            case '\r': output += "\\r"; break;
            case '\t': output += "\\t"; break;
            default: output += c; break;
        }
    }

    return output;
}

std::string buildJson(const EEGAdviceInput& input, const std::string& advice) {
    std::stringstream ss;

    ss << "{";
    ss << "\"state\":\"" << escapeJson(input.state) << "\",";
    ss << "\"focus\":" << input.focus << ",";
    ss << "\"fatigue\":" << input.fatigue << ",";
    ss << "\"relax\":" << input.relax << ",";
    ss << "\"load\":" << input.load << ",";
    ss << "\"quality\":" << input.quality << ",";
    ss << "\"confidence\":" << input.confidence << ",";
    ss << "\"focusTrend\":" << input.focusTrend << ",";
    ss << "\"fatigueTrend\":" << input.fatigueTrend << ",";
    ss << "\"relaxTrend\":" << input.relaxTrend << ",";
    ss << "\"loadTrend\":" << input.loadTrend << ",";
    ss << "\"direction\":\"" << escapeJson(buildDirection(input)) << "\",";
    ss << "\"advice\":\"" << escapeJson(advice) << "\",";
    ss << "\"local\":true,";
    ss << "\"model\":\"qwen2.5-1.5b-instruct-q4_k_m\"";
    ss << "}";

    return ss.str();
}

bool extractStringField(const std::string& content, const std::string& objectName,
                        const std::string& fieldName, std::string& value) {
    std::regex nestedRegex("\"" + objectName + "\"\\s*:\\s*\\{[^}]*\"" +
                           fieldName + "\"\\s*:\\s*\"([^\"]*)\"");
    std::smatch match;
    if (std::regex_search(content, match, nestedRegex)) {
        value = match[1].str();
        return true;
    }

    std::regex flatRegex("\"" + fieldName + "\"\\s*:\\s*\"([^\"]*)\"");
    if (std::regex_search(content, match, flatRegex)) {
        value = match[1].str();
        return true;
    }

    return false;
}

bool extractIntField(const std::string& content, const std::string& objectName,
                     const std::string& fieldName, int& value) {
    std::regex nestedRegex("\"" + objectName + "\"\\s*:\\s*\\{[^}]*\"" +
                           fieldName + "\"\\s*:\\s*(-?[0-9]+)");
    std::smatch match;
    if (std::regex_search(content, match, nestedRegex)) {
        value = std::stoi(match[1].str());
        return true;
    }

    std::regex flatRegex("\"" + fieldName + "\"\\s*:\\s*(-?[0-9]+)");
    if (std::regex_search(content, match, flatRegex)) {
        value = std::stoi(match[1].str());
        return true;
    }

    return false;
}

bool extractFloatField(const std::string& content, const std::string& objectName,
                       const std::string& fieldName, float& value) {
    std::regex nestedRegex("\"" + objectName + "\"\\s*:\\s*\\{[^}]*\"" +
                           fieldName + "\"\\s*:\\s*(-?[0-9]+(?:\\.[0-9]+)?)");
    std::smatch match;
    if (std::regex_search(content, match, nestedRegex)) {
        value = std::stof(match[1].str());
        return true;
    }

    std::regex flatRegex("\"" + fieldName + "\"\\s*:\\s*(-?[0-9]+(?:\\.[0-9]+)?)");
    if (std::regex_search(content, match, flatRegex)) {
        value = std::stof(match[1].str());
        return true;
    }

    return false;
}

bool loadCurrentDataFromJson(const std::string& path, EEGAdviceInput& input) {
    std::ifstream inFile(path);
    if (!inFile.is_open()) {
        return false;
    }

    std::stringstream buffer;
    buffer << inFile.rdbuf();
    std::string content = buffer.str();

    bool ok = true;
    ok = extractStringField(content, "summary", "state", input.state) && ok;
    extractStringField(content, "summary", "direction", input.direction);

    ok = extractIntField(content, "metrics", "focus", input.focus) && ok;
    ok = extractIntField(content, "metrics", "fatigue", input.fatigue) && ok;
    ok = extractIntField(content, "metrics", "relax", input.relax) && ok;
    ok = extractIntField(content, "metrics", "load", input.load) && ok;
    ok = extractIntField(content, "metrics", "quality", input.quality) && ok;
    ok = extractFloatField(content, "metrics", "confidence", input.confidence) && ok;

    ok = extractIntField(content, "trend", "focus", input.focusTrend) && ok;
    ok = extractIntField(content, "trend", "fatigue", input.fatigueTrend) && ok;
    ok = extractIntField(content, "trend", "relax", input.relaxTrend) && ok;
    ok = extractIntField(content, "trend", "load", input.loadTrend) && ok;

    return ok;
}

int readOldSequenceFromToApp(const std::string& path) {
    std::ifstream inFile(path);
    if (!inFile.is_open()) {
        return 0;
    }

    std::stringstream buffer;
    buffer << inFile.rdbuf();

    std::smatch match;
    std::regex sequenceRegex("\"sequence\"\\s*:\\s*([0-9]+)");
    std::string content = buffer.str();

    if (!std::regex_search(content, match, sequenceRegex)) {
        return 0;
    }

    try {
        return std::stoi(match[1].str());
    } catch (...) {
        return 0;
    }
}

std::string buildToAppJson(const std::string& json, int sequence) {
    if (json.empty() || json[0] != '{') {
        return json;
    }

    return "{\"sequence\":" + std::to_string(sequence) + "," + json.substr(1);
}

bool writeJsonAtomic(const std::string& path, const std::string& json) {
    const std::string tmpPath = "ToApp.tmp";

    std::ofstream outFile(tmpPath);
    if (!outFile.is_open()) {
        return false;
    }

    outFile << json << std::endl;
    outFile.close();

    if (!outFile) {
        return false;
    }

#ifdef _WIN32
    return MoveFileExA(tmpPath.c_str(), path.c_str(), MOVEFILE_REPLACE_EXISTING) != 0;
#else
    return std::rename(tmpPath.c_str(), path.c_str()) == 0;
#endif
}

std::string mockModelOutput(const EEGAdviceInput& input) {
    return fallbackAdvice(input) + " [end of text]";
}

#ifndef _WIN32
std::string runCommand(const std::string& cmd) {
    std::array<char, 256> buffer{};
    std::string result;

    FILE* pipe = popen(cmd.c_str(), "r");
    if (!pipe) {
        return "";
    }

    while (fgets(buffer.data(), buffer.size(), pipe) != nullptr) {
        result += buffer.data();
    }

    int ret = pclose(pipe);
    (void)ret;

    return result;
}
#endif

std::string runModel(const EEGAdviceInput& input) {
    std::string prompt = buildPrompt(input);

#if USE_MOCK_MODEL
    return mockModelOutput(input);
#else
    std::string cmd =
        "cd /data/oh-llama.cpp && "
        "./lib/ld-linux-aarch64.so.1 "
        "--library-path /data/oh-llama.cpp/lib:/data/oh-llama.cpp/lib/lib "
        "./build/bin/llama-cli "
        "-m /data/models/qwen2.5-1.5b-instruct-q4_k_m-00001-of-00001.gguf "
        "--log-disable "
        "-no-cnv "
        "--no-display-prompt "
        "--temp 0.1 "
        "--top-p 0.5 "
        "--repeat-penalty 1.15 "
        "-n 22 "
        "-p '" + prompt + "' 2>/dev/null";

    return runCommand(cmd);
#endif
}

EEGAdviceInput parseInput(int argc, char* argv[]) {
    EEGAdviceInput input;

    if (argc >= 12) {
        input.state = argv[1];

        input.focus = std::stoi(argv[2]);
        input.fatigue = std::stoi(argv[3]);
        input.relax = std::stoi(argv[4]);
        input.load = std::stoi(argv[5]);

        input.quality = std::stoi(argv[6]);
        input.confidence = std::stof(argv[7]);

        input.focusTrend = std::stoi(argv[8]);
        input.fatigueTrend = std::stoi(argv[9]);
        input.relaxTrend = std::stoi(argv[10]);
        input.loadTrend = std::stoi(argv[11]);

        return input;
    }

    input.state = "relaxed";
    input.focus = 31;
    input.fatigue = 31;
    input.relax = 68;
    input.load = 51;
    input.quality = 85;
    input.confidence = 0.85f;
    input.focusTrend = 1;
    input.fatigueTrend = 0;
    input.relaxTrend = -1;
    input.loadTrend = 1;

    return input;
}

int main(int argc, char* argv[]) {
#ifdef _WIN32
    SetConsoleOutputCP(CP_UTF8);
    SetConsoleCP(CP_UTF8);
#endif

    EEGAdviceInput input;
    if (!loadCurrentDataFromJson("currentData.json", input)) {
        input = parseInput(argc, argv);
    }

    std::string rawOutput = runModel(input);
    std::string advice = cleanOutput(rawOutput, input);

    std::string json = buildJson(input, advice);
    int newSequence = readOldSequenceFromToApp("ToApp.json") + 1;
    if (newSequence <= 0) {
        newSequence = 1;
    }

    std::string toAppJson = buildToAppJson(json, newSequence);
    writeJsonAtomic("ToApp.json", toAppJson);

    std::cout << toAppJson << std::endl;

    return 0;
}
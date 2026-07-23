#include <algorithm>
#include <cerrno>
#include <cmath>
#include <cstdio>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <regex>
#include <sstream>
#include <string>

#ifdef _WIN32
#include <filesystem>
#else
#include <sys/stat.h>
#include <sys/types.h>
#endif

namespace {

#ifdef _WIN32
const std::string RUNTIME_DIR = "./runtime";
#else
const std::string BASE_DIR = "/data/eeg_health";
const std::string RUNTIME_DIR = "/data/eeg_health/runtime";
#endif

const std::string BANDS_JSON_PATH = RUNTIME_DIR + "/bands.json";
const std::string ORIGIN_JSON_PATH = RUNTIME_DIR + "/origin.json";
const std::string CURRENT_JSON_PATH = RUNTIME_DIR + "/currentData.json";
const std::string LAST_JSON_PATH = RUNTIME_DIR + "/lastData.json";
const std::string CURRENT_TMP_PATH = RUNTIME_DIR + "/currentData.json.tmp";
const std::string LAST_TMP_PATH = RUNTIME_DIR + "/lastData.json.tmp";

constexpr int DEFAULT_SAMPLE_RATE = 250;
constexpr int DEFAULT_FRAMES_PER_WINDOW = 24;
constexpr int DEFAULT_UPDATE_STEP_FRAMES = 6;
constexpr double DEFAULT_WINDOW_SECONDS = 4.032;
constexpr double EPSILON = 1e-9;
constexpr int TREND_THRESHOLD = 5;

struct EEGBands {
    double delta = 0.0;
    double theta = 0.0;
    double alpha = 0.0;
    double beta = 0.0;
};

struct EEGChannelBands {
    EEGBands ch1;
    EEGBands ch2;
};

struct EEGMetrics {
    int focus = 0;
    int fatigue = 0;
    int relax = 0;
    int load = 0;
    int quality = 0;
    double confidence = 0.0;
};

struct EEGTrend {
    int focusTrend = 0;
    int fatigueTrend = 0;
    int relaxTrend = 0;
    int loadTrend = 0;
};

struct EEGSummary {
    std::string state = "normal";
    std::string direction = "keep_observing";
};

struct BandsInput {
    EEGChannelBands channels;
    EEGBands fusion;
    int sampleRate = DEFAULT_SAMPLE_RATE;
    int framesPerWindow = DEFAULT_FRAMES_PER_WINDOW;
    int updateStepFrames = DEFAULT_UPDATE_STEP_FRAMES;
    double windowSeconds = DEFAULT_WINDOW_SECONDS;
    int sequenceStart = 0;
    int sequenceEnd = 0;
    bool valid = true;
    bool crcChecked = false;
    bool fallback = false;
    bool hasFusion = false;
    bool ch1Valid = true;
    bool ch2Valid = true;
    std::string fusionMode;
    std::string source = "unknown";
    std::string inputName = "bands.json";
};

int clampToInt(double value, int minValue = 0, int maxValue = 100) {
    if (!std::isfinite(value)) {
        return minValue;
    }

    int rounded = static_cast<int>(std::lround(value));
    if (rounded < minValue) {
        return minValue;
    }
    if (rounded > maxValue) {
        return maxValue;
    }
    return rounded;
}

double clampDouble(double value, double minValue = 0.0, double maxValue = 1.0) {
    if (!std::isfinite(value)) {
        return minValue;
    }
    if (value < minValue) {
        return minValue;
    }
    if (value > maxValue) {
        return maxValue;
    }
    return value;
}

EEGBands fuseBands(const EEGChannelBands& channels) {
    EEGBands fused;
    fused.delta = (channels.ch1.delta + channels.ch2.delta) * 0.5;
    fused.theta = (channels.ch1.theta + channels.ch2.theta) * 0.5;
    fused.alpha = (channels.ch1.alpha + channels.ch2.alpha) * 0.5;
    fused.beta = (channels.ch1.beta + channels.ch2.beta) * 0.5;
    return fused;
}

EEGBands fuseBands(const BandsInput& input) {
    if (input.hasFusion) {
        return input.fusion;
    }
    if (input.ch1Valid && !input.ch2Valid) {
        return input.channels.ch1;
    }
    if (!input.ch1Valid && input.ch2Valid) {
        return input.channels.ch2;
    }
    return fuseBands(input.channels);
}

std::string normalizeMode(const BandsInput& input) {
    if (!input.fusionMode.empty()) {
        if (input.fusionMode == "single_channel_ch1") {
            return "single_channel";
        }
        return input.fusionMode;
    }
    if (input.ch1Valid && !input.ch2Valid) {
        return "single_channel";
    }
    if (input.ch1Valid && input.ch2Valid) {
        return "dual_channel";
    }
    if (!input.ch1Valid && input.ch2Valid) {
        return "single_channel_ch2";
    }
    return "invalid";
}

bool ensureDir(const std::string& path) {
#ifdef _WIN32
    std::filesystem::create_directories(path);
    return true;
#else
    if (path.empty()) {
        return false;
    }

    std::string current;
    size_t pos = 0;
    if (path[0] == '/') {
        current = "/";
        pos = 1;
    }

    while (pos <= path.size()) {
        size_t next = path.find('/', pos);
        std::string part = path.substr(pos, next == std::string::npos ? std::string::npos : next - pos);
        if (!part.empty()) {
            if (!current.empty() && current.back() != '/') {
                current += "/";
            }
            current += part;

            struct stat st {};
            if (stat(current.c_str(), &st) != 0) {
#ifdef _WIN32
                if (_mkdir(current.c_str()) != 0 && errno != EEXIST) {
#else
                if (mkdir(current.c_str(), 0755) != 0 && errno != EEXIST) {
#endif
                    std::cerr << "[dataproc] mkdir failed: " << current << ", errno=" << errno << std::endl;
                    return false;
                }
            }
        }

        if (next == std::string::npos) {
            break;
        }
        pos = next + 1;
    }

    return true;
#endif
}

bool readTextFile(const std::string& path, std::string& content) {
    std::ifstream in(path);
    if (!in.is_open()) {
        return false;
    }

    std::stringstream buffer;
    buffer << in.rdbuf();
    content = buffer.str();
    return true;
}

bool writeTextAtomic(const std::string& tmpPath, const std::string& finalPath, const std::string& content) {
    std::ofstream out(tmpPath, std::ios::binary);
    if (!out.is_open()) {
        std::cerr << "[dataproc] failed to open tmp file: " << tmpPath << std::endl;
        return false;
    }

    out << content;
    out.flush();
    if (!out.good()) {
        std::cerr << "[dataproc] failed to write tmp file: " << tmpPath << std::endl;
        return false;
    }
    out.close();

#ifdef _WIN32
    std::remove(finalPath.c_str());
#endif
    if (std::rename(tmpPath.c_str(), finalPath.c_str()) != 0) {
        std::cerr << "[dataproc] rename failed: " << tmpPath << " -> " << finalPath
                  << ", errno=" << errno << std::endl;
        return false;
    }

    return true;
}

bool extractDoubleField(const std::string& content, const std::string& fieldName, double& value) {
    std::regex fieldRegex("\"" + fieldName + "\"\\s*:\\s*(-?[0-9]+(?:\\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)");
    std::smatch match;
    if (!std::regex_search(content, match, fieldRegex)) {
        return false;
    }

    try {
        value = std::stod(match[1].str());
        return true;
    } catch (...) {
        return false;
    }
}

bool extractIntField(const std::string& content, const std::string& fieldName, int& value) {
    std::regex fieldRegex("\"" + fieldName + "\"\\s*:\\s*(-?[0-9]+)");
    std::smatch match;
    if (!std::regex_search(content, match, fieldRegex)) {
        return false;
    }

    try {
        value = std::stoi(match[1].str());
        return true;
    } catch (...) {
        return false;
    }
}

bool extractBoolField(const std::string& content, const std::string& fieldName, bool& value) {
    std::regex fieldRegex("\"" + fieldName + "\"\\s*:\\s*(true|false)");
    std::smatch match;
    if (!std::regex_search(content, match, fieldRegex)) {
        return false;
    }

    value = match[1].str() == "true";
    return true;
}

bool extractStringField(const std::string& content, const std::string& fieldName, std::string& value) {
    std::regex fieldRegex("\"" + fieldName + "\"\\s*:\\s*\"([^\"]*)\"");
    std::smatch match;
    if (!std::regex_search(content, match, fieldRegex)) {
        return false;
    }

    value = match[1].str();
    return true;
}

bool extractObject(const std::string& content, const std::string& objectName, std::string& objectText) {
    std::regex startRegex("\"" + objectName + "\"\\s*:\\s*\\{");
    std::smatch match;
    if (!std::regex_search(content, match, startRegex)) {
        return false;
    }

    size_t start = static_cast<size_t>(match.position(0) + match.length(0) - 1);
    int depth = 0;
    for (size_t i = start; i < content.size(); ++i) {
        if (content[i] == '{') {
            ++depth;
        } else if (content[i] == '}') {
            --depth;
            if (depth == 0) {
                objectText = content.substr(start, i - start + 1);
                return true;
            }
        }
    }

    return false;
}

bool extractBandsObject(const std::string& channelsObject, const std::string& channelName, EEGBands& bands) {
    std::string channelObject;
    if (!extractObject(channelsObject, channelName, channelObject)) {
        return false;
    }

    bool ok = true;
    ok = extractDoubleField(channelObject, "delta", bands.delta) && ok;
    ok = extractDoubleField(channelObject, "theta", bands.theta) && ok;
    ok = extractDoubleField(channelObject, "alpha", bands.alpha) && ok;
    ok = extractDoubleField(channelObject, "beta", bands.beta) && ok;
    return ok;
}

bool extractChannelValid(const std::string& channelsObject, const std::string& channelName, bool& valid) {
    std::string channelObject;
    if (!extractObject(channelsObject, channelName, channelObject)) {
        return false;
    }
    return extractBoolField(channelObject, "valid", valid);
}

bool loadBandsFromJson(const std::string& path, BandsInput& input) {
    std::string content;
    if (!readTextFile(path, content)) {
        return false;
    }

    std::string channelsObject;
    if (!extractObject(content, "channels", channelsObject)) {
        return false;
    }

    bool ok = true;
    ok = extractBandsObject(channelsObject, "ch1", input.channels.ch1) && ok;
    ok = extractBandsObject(channelsObject, "ch2", input.channels.ch2) && ok;
    extractChannelValid(channelsObject, "ch1", input.ch1Valid);
    extractChannelValid(channelsObject, "ch2", input.ch2Valid);

    std::string fusionObject;
    if (extractObject(content, "fusion", fusionObject)) {
        bool fusionValid = true;
        extractBoolField(fusionObject, "valid", fusionValid);
        input.hasFusion = fusionValid && extractDoubleField(fusionObject, "delta", input.fusion.delta)
                         && extractDoubleField(fusionObject, "theta", input.fusion.theta)
                         && extractDoubleField(fusionObject, "alpha", input.fusion.alpha)
                         && extractDoubleField(fusionObject, "beta", input.fusion.beta);
        extractStringField(fusionObject, "mode", input.fusionMode);
    }

    extractIntField(content, "sampleRate", input.sampleRate);
    extractIntField(content, "framesPerWindow", input.framesPerWindow);
    extractIntField(content, "updateStepFrames", input.updateStepFrames);
    extractDoubleField(content, "windowSeconds", input.windowSeconds);
    extractIntField(content, "sequenceStart", input.sequenceStart);
    extractIntField(content, "sequenceEnd", input.sequenceEnd);
    extractStringField(content, "source", input.source);
    if (input.fusionMode.empty()) {
        extractStringField(content, "mode", input.fusionMode);
    }

    std::string debugObject;
    if (extractObject(content, "debug", debugObject)) {
        extractBoolField(debugObject, "valid", input.valid);
        extractBoolField(debugObject, "crcChecked", input.crcChecked);
    }

    return ok;
}

bool loadFlatBandsFromJson(const std::string& path, BandsInput& input) {
    std::string content;
    if (!readTextFile(path, content)) {
        return false;
    }

    EEGBands bands;
    bool ok = true;
    ok = extractDoubleField(content, "delta", bands.delta) && ok;
    ok = extractDoubleField(content, "theta", bands.theta) && ok;
    ok = extractDoubleField(content, "alpha", bands.alpha) && ok;
    ok = extractDoubleField(content, "beta", bands.beta) && ok;
    if (!ok) {
        return false;
    }

    input.channels.ch1 = bands;
    input.channels.ch2 = bands;
    input.fusion = bands;
    input.hasFusion = true;
    input.ch1Valid = true;
    input.ch2Valid = false;
    input.fusionMode = "single_channel";
    input.source = "origin.json";
    input.inputName = "origin.json";
    return true;
}

#ifdef _WIN32
BandsInput fallbackBands() {
    BandsInput input;
    input.fallback = true;
    input.sequenceStart = 1;
    input.sequenceEnd = 24;
    input.channels.ch1 = {123.4, 456.7, 789.0, 321.0};
    input.channels.ch2 = {111.1, 444.4, 666.6, 333.3};
    input.ch1Valid = true;
    input.ch2Valid = false;
    input.fusionMode = "single_channel";
    input.source = "fallback";
    return input;
}
#endif

EEGMetrics analyzeBands(const BandsInput& input, const EEGBands& fused) {
    EEGMetrics metrics;

    double delta = std::max(0.0, fused.delta);
    double theta = std::max(0.0, fused.theta);
    double alpha = std::max(0.0, fused.alpha);
    double beta = std::max(0.0, fused.beta);
    double total = delta + theta + alpha + beta + EPSILON;

    double alphaRatio = alpha / total;
    double betaRatio = beta / total;
    double thetaRatio = theta / total;
    double deltaRatio = delta / total;
    double betaAlphaRatio = beta / (alpha + EPSILON);

    metrics.focus = clampToInt(50.0 + betaRatio * 80.0 - thetaRatio * 60.0 - deltaRatio * 40.0);
    metrics.relax = clampToInt(40.0 + alphaRatio * 100.0 - betaRatio * 40.0);
    metrics.fatigue = clampToInt(30.0 + thetaRatio * 80.0 + deltaRatio * 60.0 - betaRatio * 30.0);
    metrics.load = clampToInt(30.0 + betaRatio * 90.0 + betaAlphaRatio * 10.0);

    int quality = 85;
    if (total < 1e-6) {
        quality -= 45;
    }
    if (!input.valid) {
        quality -= 35;
    }

    double maxBand = std::max(std::max(delta, theta), std::max(alpha, beta));
    double minBand = std::min(std::min(delta, theta), std::min(alpha, beta));
    if (maxBand > 0.0 && minBand / maxBand < 1e-6) {
        quality -= 10;
    }
    if (maxBand > total * 0.92) {
        quality -= 15;
    }

    metrics.quality = clampToInt(quality);
    metrics.confidence = clampDouble(static_cast<double>(metrics.quality) / 100.0);
    return metrics;
}

bool loadLastMetrics(const std::string& path, EEGMetrics& last) {
    std::string content;
    if (!readTextFile(path, content)) {
        return false;
    }

    bool ok = true;
    ok = extractIntField(content, "focus", last.focus) && ok;
    ok = extractIntField(content, "fatigue", last.fatigue) && ok;
    ok = extractIntField(content, "relax", last.relax) && ok;
    ok = extractIntField(content, "load", last.load) && ok;
    ok = extractIntField(content, "quality", last.quality) && ok;
    ok = extractDoubleField(content, "confidence", last.confidence) && ok;
    return ok;
}

int trendValue(int current, int last) {
    if (current > last + TREND_THRESHOLD) {
        return 1;
    }
    if (current < last - TREND_THRESHOLD) {
        return -1;
    }
    return 0;
}

EEGTrend calcTrend(const EEGMetrics& current, const EEGMetrics* last) {
    EEGTrend trend;
    if (last == nullptr) {
        return trend;
    }

    trend.focusTrend = trendValue(current.focus, last->focus);
    trend.fatigueTrend = trendValue(current.fatigue, last->fatigue);
    trend.relaxTrend = trendValue(current.relax, last->relax);
    trend.loadTrend = trendValue(current.load, last->load);
    return trend;
}

EEGSummary summarize(const EEGMetrics& metrics) {
    EEGSummary summary;

    if (metrics.quality < 50) {
        summary.state = "unstable";
        summary.direction = "check_signal_or_adjust_device";
    } else if (metrics.load >= 90) {
        summary.state = "stress";
        summary.direction = "breathing_relax";
    } else if (metrics.fatigue >= 70) {
        summary.state = "fatigue";
        summary.direction = "rest_recovery";
    } else if (metrics.focus >= 60 && metrics.fatigue < 60) {
        summary.state = "focused";
        summary.direction = "continue_work";
    } else if (metrics.load >= 70) {
        summary.state = "stress";
        summary.direction = "breathing_relax";
    } else if (metrics.relax >= 60 && metrics.focus < 60) {
        summary.state = "relaxed";
        summary.direction = "low_pressure_activity";
    } else {
        summary.state = "normal";
        summary.direction = "keep_observing";
    }

    return summary;
}

void writeBandsJson(std::ostringstream& ss, const std::string& indent, const EEGBands& bands) {
    ss << indent << "\"delta\": " << std::fixed << std::setprecision(6) << bands.delta << ",\n";
    ss << indent << "\"theta\": " << std::fixed << std::setprecision(6) << bands.theta << ",\n";
    ss << indent << "\"alpha\": " << std::fixed << std::setprecision(6) << bands.alpha << ",\n";
    ss << indent << "\"beta\": " << std::fixed << std::setprecision(6) << bands.beta << "\n";
}

std::string buildCurrentJson(const BandsInput& input, const EEGBands& fused,
                             const EEGMetrics& metrics, const EEGTrend& trend,
                             const EEGSummary& summary) {
    std::ostringstream ss;
    std::string channelMode = normalizeMode(input);
    std::string dataSource = input.fallback ? "fallback_bands" : "real_uart_frame";

    ss << "{\n";
    ss << "  \"mode\": \"" << channelMode << "\",\n";
    ss << "  \"channelMode\": \"" << channelMode << "\",\n";
    ss << "  \"ch1Valid\": " << (input.ch1Valid ? "true" : "false") << ",\n";
    ss << "  \"ch2Valid\": " << (input.ch2Valid ? "true" : "false") << ",\n";
    ss << "  \"channelStatus\": {\n";
    ss << "    \"ch1\": \"" << (input.ch1Valid ? "active" : "inactive") << "\",\n";
    ss << "    \"ch2\": \"" << (input.ch2Valid ? "active" : "reserved") << "\"\n";
    ss << "  },\n";
    ss << "  \"dataSource\": \"" << dataSource << "\",\n";
    ss << "  \"sourceName\": \"" << input.source << "\",\n";
    ss << "  \"bands\": {\n";
    ss << "    \"ch1\": {\n";
    writeBandsJson(ss, "      ", input.channels.ch1);
    ss << "    },\n";
    ss << "    \"ch2\": {\n";
    writeBandsJson(ss, "      ", input.channels.ch2);
    ss << "    },\n";
    ss << "    \"fusion\": {\n";
    writeBandsJson(ss, "      ", fused);
    ss << "    }\n";
    ss << "  },\n";
    ss << "  \"metrics\": {\n";
    ss << "    \"focus\": " << metrics.focus << ",\n";
    ss << "    \"fatigue\": " << metrics.fatigue << ",\n";
    ss << "    \"relax\": " << metrics.relax << ",\n";
    ss << "    \"load\": " << metrics.load << ",\n";
    ss << "    \"quality\": " << metrics.quality << ",\n";
    ss << "    \"confidence\": " << std::fixed << std::setprecision(3) << metrics.confidence << ",\n";
    ss << "    \"focusTrend\": " << trend.focusTrend << ",\n";
    ss << "    \"fatigueTrend\": " << trend.fatigueTrend << ",\n";
    ss << "    \"relaxTrend\": " << trend.relaxTrend << ",\n";
    ss << "    \"loadTrend\": " << trend.loadTrend << "\n";
    ss << "  },\n";
    ss << "  \"trend\": {\n";
    ss << "    \"focusTrend\": " << trend.focusTrend << ",\n";
    ss << "    \"fatigueTrend\": " << trend.fatigueTrend << ",\n";
    ss << "    \"relaxTrend\": " << trend.relaxTrend << ",\n";
    ss << "    \"loadTrend\": " << trend.loadTrend << "\n";
    ss << "  },\n";
    ss << "  \"summary\": {\n";
    ss << "    \"state\": \"" << summary.state << "\",\n";
    ss << "    \"direction\": \"" << summary.direction << "\"\n";
    ss << "  },\n";
    ss << "  \"source\": {\n";
    ss << "    \"input\": \"" << (input.fallback ? "fallback_bands" : input.inputName) << "\",\n";
    ss << "    \"dataSource\": \"" << dataSource << "\",\n";
    ss << "    \"sourceName\": \"" << input.source << "\",\n";
    ss << "    \"channelMode\": \"" << channelMode << "\",\n";
    ss << "    \"ch1Valid\": " << (input.ch1Valid ? "true" : "false") << ",\n";
    ss << "    \"ch2Valid\": " << (input.ch2Valid ? "true" : "false") << ",\n";
    ss << "    \"sampleRate\": " << input.sampleRate << ",\n";
    ss << "    \"windowSeconds\": " << std::fixed << std::setprecision(3) << input.windowSeconds << ",\n";
    ss << "    \"sequenceStart\": " << input.sequenceStart << ",\n";
    ss << "    \"sequenceEnd\": " << input.sequenceEnd << ",\n";
    ss << "    \"valid\": " << (input.valid ? "true" : "false") << ",\n";
    ss << "    \"crcChecked\": " << (input.crcChecked ? "true" : "false") << ",\n";
    ss << "    \"fusionMode\": \"" << channelMode << "\",\n";
    ss << "    \"mode\": \"" << channelMode << "\"\n";
    ss << "  },\n";
    ss << "  \"state\": \"" << summary.state << "\",\n";
    ss << "  \"direction\": \"" << summary.direction << "\",\n";
    ss << "  \"focus\": " << metrics.focus << ",\n";
    ss << "  \"fatigue\": " << metrics.fatigue << ",\n";
    ss << "  \"relax\": " << metrics.relax << ",\n";
    ss << "  \"load\": " << metrics.load << ",\n";
    ss << "  \"quality\": " << metrics.quality << ",\n";
    ss << "  \"confidence\": " << std::fixed << std::setprecision(3) << metrics.confidence << ",\n";
    ss << "  \"focusTrend\": " << trend.focusTrend << ",\n";
    ss << "  \"fatigueTrend\": " << trend.fatigueTrend << ",\n";
    ss << "  \"relaxTrend\": " << trend.relaxTrend << ",\n";
    ss << "  \"loadTrend\": " << trend.loadTrend << "\n";
    ss << "}\n";
    return ss.str();
}

std::string buildLastJson(const EEGMetrics& metrics, const EEGSummary& summary,
                          const std::string& mode) {
    std::ostringstream ss;
    ss << "{\n";
    ss << "  \"mode\": \"" << mode << "\",\n";
    ss << "  \"focus\": " << metrics.focus << ",\n";
    ss << "  \"fatigue\": " << metrics.fatigue << ",\n";
    ss << "  \"relax\": " << metrics.relax << ",\n";
    ss << "  \"load\": " << metrics.load << ",\n";
    ss << "  \"quality\": " << metrics.quality << ",\n";
    ss << "  \"confidence\": " << std::fixed << std::setprecision(3) << metrics.confidence << ",\n";
    ss << "  \"state\": \"" << summary.state << "\"\n";
    ss << "}\n";
    return ss.str();
}

}  // namespace

int main() {
#ifdef _WIN32
    std::cout << "[dataproc] Windows mode." << std::endl;
    ensureDir(RUNTIME_DIR);
#else
    ensureDir(BASE_DIR);
    ensureDir(RUNTIME_DIR);
#endif

    BandsInput input;
#ifdef _WIN32
    std::cout << "[dataproc] reading " << BANDS_JSON_PATH << std::endl;
#endif
    if (loadBandsFromJson(BANDS_JSON_PATH, input)) {
        input.inputName = "bands.json";
    } else if (loadFlatBandsFromJson(ORIGIN_JSON_PATH, input)) {
        std::cerr << "[dataproc] warning: " << BANDS_JSON_PATH
                  << " not found or invalid, using " << ORIGIN_JSON_PATH << std::endl;
    } else {
#ifdef _WIN32
        std::cout << "[dataproc] bands.json/origin.json not found, using built-in mock bands." << std::endl;
        input = fallbackBands();
#else
        std::cerr << "[dataproc] ERROR: input not found or invalid: "
                  << BANDS_JSON_PATH << " or " << ORIGIN_JSON_PATH << std::endl;
        return 1;
#endif
    }

    EEGBands fused = fuseBands(input);
    EEGMetrics metrics = analyzeBands(input, fused);

    EEGMetrics last {};
    bool hasLast = loadLastMetrics(LAST_JSON_PATH, last);

    EEGTrend trend = calcTrend(metrics, hasLast ? &last : nullptr);
    EEGSummary summary = summarize(metrics);

    std::string currentJson = buildCurrentJson(input, fused, metrics, trend, summary);
    std::string lastJson = buildLastJson(metrics, summary, normalizeMode(input));

    bool ok = true;
    ok = writeTextAtomic(CURRENT_TMP_PATH, CURRENT_JSON_PATH, currentJson) && ok;
    ok = writeTextAtomic(LAST_TMP_PATH, LAST_JSON_PATH, lastJson) && ok;

#ifdef _WIN32
    if (ok) {
        std::cout << "[dataproc] currentData updated: " << CURRENT_JSON_PATH << std::endl;
        std::cout << "[dataproc] lastData updated: " << LAST_JSON_PATH << std::endl;
    }
#endif

    std::cout << "========== currentData ==========" << std::endl;
    std::cout << currentJson << std::endl;
    std::cout << "========== lastData ==========" << std::endl;
    std::cout << lastJson << std::endl;

    return ok ? 0 : 1;
}

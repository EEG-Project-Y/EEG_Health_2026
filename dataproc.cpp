// dataproc.cpp
#include <iostream>
#include <fstream>
#include <cmath>
#include <string>
#include <sstream>

using namespace std;

struct EEGInput {
    float delta = 0.0f;
    float theta = 0.0f;
    float alpha = 0.0f;
    float beta = 0.0f;

    int quality = 0;
    float confidence = 0.0f;
};

struct EEGMetrics {
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

    string state = "normal";
};

static EEGMetrics lastData = {
    24, 36, 73, 42,
    84, 0.84f,
    0, 0, 0, 0,
    "relaxed"
};

static bool hasLastData = true;

int clampInt(int value, int minVal = 0, int maxVal = 100) {
    if (value < minVal) return minVal;
    if (value > maxVal) return maxVal;
    return value;
}

float clampFloat(float value, float minVal = 0.0f, float maxVal = 1.0f) {
    if (value < minVal) return minVal;
    if (value > maxVal) return maxVal;
    return value;
}

int trendValue(int now, int last) {
    if (!hasLastData) return 0;

    int diff = now - last;

    if (diff > 5) return 1;
    if (diff < -5) return -1;
    return 0;
}

string levelTag(const string& name, int value) {
    if (value >= 70) return name + "_high";
    if (value >= 40) return name + "_medium";
    return name + "_low";
}

string trendTag(const string& name, int trend) {
    if (trend == 1) return name + "_up";
    if (trend == -1) return name + "_down";
    return name + "_none";
}

EEGMetrics analyzeEEG(const EEGInput& input) {
    EEGMetrics m;

    float delta = max(input.delta, 0.01f);
    float theta = max(input.theta, 0.01f);
    float alpha = max(input.alpha, 0.01f);
    float beta  = max(input.beta, 0.01f);

    float focusRaw   = beta / (alpha + theta);
    float fatigueRaw = theta / beta;
    float relaxRaw   = alpha / beta;
    float loadRaw    = beta / (alpha + theta + delta);

    m.focus   = clampInt((int)(focusRaw * 70));
    m.fatigue = clampInt((int)(fatigueRaw * 45));
    m.relax   = clampInt((int)(relaxRaw * 45));
    m.load    = clampInt((int)(loadRaw * 130));

    m.quality = clampInt(input.quality);
    m.confidence = clampFloat(input.confidence);

    if (m.quality < 50) {
        m.state = "unstable";
    } else if (m.fatigue >= 70) {
        m.state = "fatigue";
    } else if (m.load >= 75) {
        m.state = "stress";
    } else if (m.focus >= 70) {
        m.state = "focused";
    } else if (m.relax >= 65) {
        m.state = "relaxed";
    } else {
        m.state = "normal";
    }

    return m;
}

void fillTrend(EEGMetrics& currentData) {
    currentData.focusTrend = trendValue(currentData.focus, lastData.focus);
    currentData.fatigueTrend = trendValue(currentData.fatigue, lastData.fatigue);
    currentData.relaxTrend = trendValue(currentData.relax, lastData.relax);
    currentData.loadTrend = trendValue(currentData.load, lastData.load);
}

string buildSummary(const EEGMetrics& currentData) {
    stringstream ss;

    ss << "[";
    ss << "\"" << levelTag("focus", currentData.focus) << "\",";
    ss << "\"" << levelTag("fatigue", currentData.fatigue) << "\",";
    ss << "\"" << levelTag("relax", currentData.relax) << "\",";
    ss << "\"" << levelTag("load", currentData.load) << "\",";
    ss << "\"" << trendTag("focus", currentData.focusTrend) << "\"";
    ss << "]";

    return ss.str();
}

string buildDataJSON(const EEGMetrics& m, bool withSummary) {
    stringstream ss;

    ss << "{\n";
    ss << "  \"focus\": " << m.focus << ",\n";
    ss << "  \"fatigue\": " << m.fatigue << ",\n";
    ss << "  \"relax\": " << m.relax << ",\n";
    ss << "  \"load\": " << m.load << ",\n";
    ss << "  \"quality\": " << m.quality << ",\n";
    ss << "  \"confidence\": " << m.confidence << ",\n";
    ss << "  \"focusTrend\": " << m.focusTrend << ",\n";
    ss << "  \"fatigueTrend\": " << m.fatigueTrend << ",\n";
    ss << "  \"relaxTrend\": " << m.relaxTrend << ",\n";
    ss << "  \"loadTrend\": " << m.loadTrend << ",\n";
    ss << "  \"state\": \"" << m.state << "\"";

    if (withSummary) {
        ss << ",\n";
        ss << "  \"summary\": " << buildSummary(m);
    }

    ss << "\n}";

    return ss.str();
}

void saveTextFile(const string& filename, const string& content) {
    ofstream file(filename);
    file << content;
    file.close();
}

string processEEGData(const EEGInput& input) {
    EEGMetrics currentData = analyzeEEG(input);

    fillTrend(currentData);

    string currentJson = buildDataJSON(currentData, true);
    string oldLastJson = buildDataJSON(lastData, false);

    lastData = currentData;

    string newLastJson = buildDataJSON(lastData, false);

    saveTextFile("currentData.json", currentJson);
    saveTextFile("lastData.json", newLastJson);

    cout << "========== currentData ==========" << endl;
    cout << currentJson << endl << endl;

    cout << "========== old lastData ==========" << endl;
    cout << oldLastJson << endl << endl;

    cout << "========== new lastData ==========" << endl;
    cout << newLastJson << endl << endl;

    return currentJson;
}

int main() {
    EEGInput input;

    input.delta = 2.4f;
    input.theta = 5.6f;
    input.alpha = 12.3f;
    input.beta = 8.1f;

    input.quality = 85;
    input.confidence = 0.85f;

    processEEGData(input);

    return 0;
}
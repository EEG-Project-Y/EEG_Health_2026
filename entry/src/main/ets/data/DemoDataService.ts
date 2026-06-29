/**
 * ============================================================================
 * DemoDataService - 模拟机专用数据源
 * ============================================================================
 *
 * 仅在 DevEco 预览 / 模拟机 / 本地调试环境下使用。
 * 真机运行时必须通过 SIMULATOR_DEMO_MODE = false 关闭此服务。
 *
 * 三阶段循环：正常专注(~15s) → 疲劳上升(~20s) → 高风险预警(~15s)
 * 每 1 秒刷新，数值平滑渐变。
 */

import { ToAppJson } from './DataService';

interface PhaseConfig {
  name: string;
  state: string;
  stateLabel: string;
  adviceZh: string;
  adviceEn: string;
  durationTicks: number;
  metrics: {
    focus: number;
    fatigue: number;
    relax: number;
    load: number;
    quality: number;
    confidence: number;
  };
}

const PHASE_A: PhaseConfig = {
  name: 'normal_focused',
  state: 'focused',
  stateLabel: 'Focused',
  adviceZh: '当前状态较稳定，可继续保持当前节奏。',
  adviceEn: 'Current state is stable. Keep it up.',
  durationTicks: 15,
  metrics: { focus: 78, fatigue: 28, relax: 52, load: 48, quality: 88, confidence: 0.88 }
};

const PHASE_B: PhaseConfig = {
  name: 'fatigue_rising',
  state: 'fatigue_rising',
  stateLabel: 'Fatigue Rising',
  adviceZh: '检测到疲劳趋势上升，建议短暂休息。',
  adviceEn: 'Fatigue trend rising. Consider a short break.',
  durationTicks: 20,
  metrics: { focus: 50, fatigue: 70, relax: 35, load: 75, quality: 82, confidence: 0.85 }
};

const PHASE_C: PhaseConfig = {
  name: 'high_risk',
  state: 'fatigue_high',
  stateLabel: 'High Risk',
  adviceZh: '当前疲劳程度较高，建议立即暂停高强度任务并休息。',
  adviceEn: 'High fatigue detected. Pause intense tasks and rest now.',
  durationTicks: 15,
  metrics: { focus: 40, fatigue: 82, relax: 30, load: 82, quality: 85, confidence: 0.90 }
};

const PHASES: PhaseConfig[] = [PHASE_A, PHASE_B, PHASE_C];

function lerp(a: number, b: number, t: number): number {
  const clamped = Math.max(0, Math.min(1, t));
  return a + (b - a) * clamped;
}

function jitter(value: number, amplitude: number): number {
  return value + (Math.random() - 0.5) * amplitude * 2;
}

export class DemoDataService {
  private static instance: DemoDataService | null = null;
  private intervalId: number = -1;
  private callback: ((data: ToAppJson) => void) | null = null;

  private sequence: number = 0;
  private tickInPhase: number = 0;
  private phaseIndex: number = 0;
  private language: number = 0;
  private prevMetrics: { focus: number; fatigue: number; relax: number; load: number; quality: number; confidence: number } =
    { focus: PHASE_A.metrics.focus, fatigue: PHASE_A.metrics.fatigue, relax: PHASE_A.metrics.relax,
      load: PHASE_A.metrics.load, quality: PHASE_A.metrics.quality, confidence: PHASE_A.metrics.confidence };

  static getInstance(): DemoDataService {
    if (!DemoDataService.instance) {
      DemoDataService.instance = new DemoDataService();
    }
    return DemoDataService.instance;
  }

  setLanguage(lang: number): void {
    this.language = lang;
  }

  getAdviceEn(zhAdvice: string): string {
    if (zhAdvice === PHASE_A.adviceZh) return PHASE_A.adviceEn;
    if (zhAdvice === PHASE_B.adviceZh) return PHASE_B.adviceEn;
    if (zhAdvice === PHASE_C.adviceZh) return PHASE_C.adviceEn;
    return zhAdvice;
  }

  getAdviceZh(enAdvice: string): string {
    if (enAdvice === PHASE_A.adviceEn) return PHASE_A.adviceZh;
    if (enAdvice === PHASE_B.adviceEn) return PHASE_B.adviceZh;
    if (enAdvice === PHASE_C.adviceEn) return PHASE_C.adviceZh;
    return enAdvice;
  }

  startReceiving(callback: (data: ToAppJson) => void, _errorCallback?: (message: string) => void, intervalMs: number = 1000): void {
    this.stopReceiving();
    this.callback = callback;
    this.sequence = 0;
    this.tickInPhase = 0;
    this.phaseIndex = 0;
    this.prevMetrics = { ...PHASE_A.metrics };
    this.generateTick();
    this.intervalId = setInterval(() => {
      this.generateTick();
    }, intervalMs);
  }

  refreshOnce(callback: (data: ToAppJson) => void, _errorCallback?: (message: string) => void): void {
    this.callback = callback;
    this.sequence = 0;
    this.tickInPhase = 0;
    this.phaseIndex = 0;
    this.prevMetrics = { ...PHASE_A.metrics };
    this.generateTick();
  }

  stopReceiving(): void {
    if (this.intervalId !== -1) {
      clearInterval(this.intervalId);
      this.intervalId = -1;
    }
  }

  private generateTick(): void {
    const phase = PHASES[this.phaseIndex];
    const progress = this.tickInPhase / Math.max(1, phase.durationTicks - 1);

    const focus = Math.round(lerp(this.prevMetrics.focus, phase.metrics.focus, progress));
    const fatigue = Math.round(lerp(this.prevMetrics.fatigue, phase.metrics.fatigue, progress));
    const relax = Math.round(lerp(this.prevMetrics.relax, phase.metrics.relax, progress));
    const load = Math.round(lerp(this.prevMetrics.load, phase.metrics.load, progress));
    const quality = Math.round(jitter(lerp(this.prevMetrics.quality, phase.metrics.quality, progress), 3));
    const confidence = Math.round(lerp(this.prevMetrics.confidence, phase.metrics.confidence, progress) * 100) / 100;

    const focusTrend = phase.metrics.focus < this.prevMetrics.focus ? -1 : (phase.metrics.focus > this.prevMetrics.focus ? 1 : 0);
    const fatigueTrend = phase.metrics.fatigue > this.prevMetrics.fatigue ? 1 : (phase.metrics.fatigue < this.prevMetrics.fatigue ? -1 : 0);
    const relaxTrend = phase.metrics.relax < this.prevMetrics.relax ? -1 : (phase.metrics.relax > this.prevMetrics.relax ? 1 : 0);
    const loadTrend = phase.metrics.load > this.prevMetrics.load ? 1 : (phase.metrics.load < this.prevMetrics.load ? -1 : 0);

    this.sequence += 1;

    const data: ToAppJson = {
      sequence: this.sequence,
      focus: Math.max(0, Math.min(100, focus)),
      fatigue: Math.max(0, Math.min(100, fatigue)),
      relax: Math.max(0, Math.min(100, relax)),
      load: Math.max(0, Math.min(100, load)),
      quality: Math.max(0, Math.min(100, quality)),
      confidence: Math.max(0, Math.min(1, confidence)),
      focusTrend: focusTrend,
      fatigueTrend: fatigueTrend,
      relaxTrend: relaxTrend,
      loadTrend: loadTrend,
      state: phase.state,
      stateLabel: phase.stateLabel,
      direction: phase.name,
      channelMode: 'single_channel',
      ch1Valid: true,
      ch2Valid: true,
      channelStatus: 'connected',
      dataSource: 'eeg_device',
      source: 'local_model',
      sourcePath: 'simulator',
      readFrom: 'simulator',
      advice: this.language === 0 ? phase.adviceZh : phase.adviceEn,
      local: true,
      model: 'qwen2.5-1.5b-instruct-q4_k_m'
    };

    this.tickInPhase += 1;
    if (this.tickInPhase >= phase.durationTicks) {
      this.prevMetrics = {
        focus: Math.max(0, Math.min(100, focus)),
        fatigue: Math.max(0, Math.min(100, fatigue)),
        relax: Math.max(0, Math.min(100, relax)),
        load: Math.max(0, Math.min(100, load)),
        quality: Math.max(0, Math.min(100, quality)),
        confidence: Math.max(0, Math.min(1, confidence))
      };
      this.phaseIndex = (this.phaseIndex + 1) % PHASES.length;
      this.tickInPhase = 0;
    }

    this.callback?.(data);
  }
}

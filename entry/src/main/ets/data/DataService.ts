import { http } from '@kit.NetworkKit';
import fileIo from '@ohos.file.fs';
import { AppConfig } from '../config/config';

export interface EegMetricsJson {
  focus?: number;
  fatigue?: number;
  relax?: number;
  load?: number;
  quality?: number;
  confidence?: number;
  focusTrend?: number;
  fatigueTrend?: number;
  relaxTrend?: number;
  loadTrend?: number;
}

export interface EegTrendJson {
  focusTrend?: number;
  fatigueTrend?: number;
  relaxTrend?: number;
  loadTrend?: number;
}

export interface EegSourceJson {
  input?: string;
  dataSource?: string;
  source?: string;
  valid?: boolean;
}

export interface EegChannelStatusJson {
  ch1?: string;
  ch2?: string;
  state?: string;
  summary?: string;
}

export interface EegSummaryJson {
  state?: string;
  direction?: string;
}

export interface ToAppJson {
  sequence?: number;
  mode?: string;
  focus?: number;
  fatigue?: number;
  relax?: number;
  load?: number;
  quality?: number;
  confidence?: number;
  focusTrend?: number;
  fatigueTrend?: number;
  relaxTrend?: number;
  loadTrend?: number;
  state?: string;
  stateLabel?: string;
  direction?: string;
  channelMode?: string;
  ch1Valid?: boolean;
  ch2Valid?: boolean;
  channelStatus?: string | EegChannelStatusJson;
  dataSource?: string;
  source?: string | EegSourceJson;
  sourcePath?: string;
  readFrom?: string;
  advice?: string;
  local?: boolean;
  model?: string;
  metrics?: EegMetricsJson;
  trend?: EegTrendJson;
  summary?: string[] | EegSummaryJson;
}

export function getNoDataState(): ToAppJson {
  return {
    sequence: 0,
    focus: 0,
    fatigue: 0,
    relax: 0,
    load: 0,
    quality: 0,
    confidence: 0,
    state: '等待数据',
    direction: 'no_data',
    channelMode: 'unknown',
    ch1Valid: false,
    ch2Valid: false,
    channelStatus: '未连接数据源',
    dataSource: 'none',
    source: 'no_data',
    advice: '暂未读取到脑电数据，请检查香橙派链路或 ToApp.json。',
    local: false,
    model: 'none'
  };
}

export function getMockDataState(): ToAppJson {
  return {
    sequence: 108,
    mode: 'focus_training',
    focus: 84,
    fatigue: 16,
    relax: 57,
    load: 38,
    quality: 96,
    confidence: 0.94,
    focusTrend: 2,
    fatigueTrend: -1,
    relaxTrend: 1,
    loadTrend: -1,
    state: 'focused',
    stateLabel: '专注',
    direction: 'focus_training',
    channelMode: 'dual_channel',
    ch1Valid: true,
    ch2Valid: true,
    channelStatus: 'connected',
    dataSource: 'eeg_device',
    source: 'local_model',
    advice: '当前专注状态良好，疲劳水平较低。建议继续保持稳定坐姿，并在 25 分钟训练后短暂休息。',
    local: true,
    model: 'qwen2.5-1.5b-instruct-q4_k_m',
    summary: [
      '72 min',
      '16 /100'
    ]
  };
}

export class DataService {
  private static instance: DataService | null = null;
  private intervalId: number = -1;
  private callback: ((data: ToAppJson) => void) | null = null;
  private errorCallback: ((message: string) => void) | null = null;

  static getInstance(): DataService {
    if (!DataService.instance) {
      DataService.instance = new DataService();
    }
    return DataService.instance;
  }

  startReceiving(callback: (data: ToAppJson) => void, errorCallback?: (message: string) => void, intervalMs: number = 1000): void {
    this.stopReceiving();
    this.callback = callback;
    this.errorCallback = errorCallback ?? null;
    this.fetchData();
    this.intervalId = setInterval(() => {
      this.fetchData();
    }, intervalMs);
  }

  refreshOnce(callback: (data: ToAppJson) => void, errorCallback?: (message: string) => void): void {
    this.callback = callback;
    this.errorCallback = errorCallback ?? null;
    this.fetchData();
  }

  stopReceiving(): void {
    if (this.intervalId !== -1) {
      clearInterval(this.intervalId);
      this.intervalId = -1;
    }
  }

  private async fetchData(): Promise<void> {
    for (let i = 0; i < AppConfig.eegHttpEndpoints.length; i++) {
      const request = http.createHttp();
      try {
        const endpoint = AppConfig.eegHttpEndpoints[i];
        const response = await request.request(endpoint, {
          method: http.RequestMethod.GET,
          connectTimeout: 2000,
          readTimeout: 2000
        });
        const raw = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
        const data = this.parseAndNormalize(raw, 'http_toapp', endpoint);
        this.callback?.(data);
        return;
      } catch (error) {
        console.error(`[DataService] fetch eeg data failed: ${JSON.stringify(error)}`);
      } finally {
        request.destroy();
      }
    }

    for (let i = 0; i < AppConfig.eegLocalFiles.length; i++) {
      const path = AppConfig.eegLocalFiles[i];
      try {
        const fallbackSource = path.indexOf('currentData.json') >= 0 ? 'currentData' : 'file_toapp';
        const raw = fileIo.readTextSync(path);
        const data = this.parseAndNormalize(raw, fallbackSource, path);
        this.callback?.(data);
        return;
      } catch (error) {
        console.error(`[DataService] read eeg file failed: ${path}, ${JSON.stringify(error)}`);
      }
    }

    if (AppConfig.enableMockFallback) {
      const data = this.normalizeData(getMockDataState(), 'eeg_device', 'ToApp.json');
      this.callback?.(data);
      return;
    }

    this.callback?.(getNoDataState());
    this.errorCallback?.('no_data');
  }

  private parseAndNormalize(raw: string, fallbackSource: string, readFrom: string): ToAppJson {
    const data = JSON.parse(raw) as ToAppJson;
    return this.normalizeData(data, fallbackSource, readFrom);
  }

  private normalizeData(data: ToAppJson, fallbackSource: string, readFrom: string): ToAppJson {
    this.applyNestedMetrics(data);
    this.applyNestedSummary(data);
    data.channelStatus = this.resolveChannelStatusLabel(data.channelStatus);

    const dataSourceLabel = this.resolveDataSourceLabel(data, fallbackSource);
    const sourceLabel = this.resolveSourceLabel(data, fallbackSource);
    if (data.dataSource === undefined || data.dataSource.length === 0) {
      data.dataSource = dataSourceLabel;
    }
    if (typeof data.source !== 'string' || data.source.length === 0) {
      data.source = sourceLabel;
    }
    data.readFrom = readFrom;
    data.sourcePath = readFrom;

    if (!this.hasDisplayData(data)) {
      throw new Error('EEG payload has no displayable data');
    }
    return data;
  }

  private applyNestedMetrics(data: ToAppJson): void {
    const metrics = data.metrics;
    if (!metrics) {
      return;
    }
    data.focus = this.firstNumber(data.focus, metrics.focus);
    data.fatigue = this.firstNumber(data.fatigue, metrics.fatigue);
    data.relax = this.firstNumber(data.relax, metrics.relax);
    data.load = this.firstNumber(data.load, metrics.load);
    data.quality = this.firstNumber(data.quality, metrics.quality);
    data.confidence = this.firstNumber(data.confidence, metrics.confidence);
    data.focusTrend = this.firstNumber(data.focusTrend, metrics.focusTrend);
    data.fatigueTrend = this.firstNumber(data.fatigueTrend, metrics.fatigueTrend);
    data.relaxTrend = this.firstNumber(data.relaxTrend, metrics.relaxTrend);
    data.loadTrend = this.firstNumber(data.loadTrend, metrics.loadTrend);
  }

  private applyNestedSummary(data: ToAppJson): void {
    if (data.trend) {
      data.focusTrend = this.firstNumber(data.focusTrend, data.trend.focusTrend);
      data.fatigueTrend = this.firstNumber(data.fatigueTrend, data.trend.fatigueTrend);
      data.relaxTrend = this.firstNumber(data.relaxTrend, data.trend.relaxTrend);
      data.loadTrend = this.firstNumber(data.loadTrend, data.trend.loadTrend);
    }
    if (typeof data.summary === 'object' && data.summary !== null && !Array.isArray(data.summary)) {
      const summary = data.summary as EegSummaryJson;
      if ((data.state === undefined || data.state.length === 0) && summary.state !== undefined) {
        data.state = summary.state;
      }
      if ((data.direction === undefined || data.direction.length === 0) && summary.direction !== undefined) {
        data.direction = summary.direction;
      }
    }
  }

  private firstNumber(primary: number | undefined, secondary: number | undefined): number | undefined {
    if (typeof primary === 'number' && primary === primary) {
      return primary;
    }
    return secondary;
  }

  private resolveDataSourceLabel(data: ToAppJson, fallbackSource: string): string {
    if (data.dataSource !== undefined && data.dataSource.length > 0) {
      return data.dataSource;
    }
    if (typeof data.source === 'string' && data.source.length > 0) {
      return data.source;
    }
    if (typeof data.source === 'object' && data.source !== null) {
      const sourceInfo = data.source as EegSourceJson;
      if (sourceInfo.dataSource !== undefined && sourceInfo.dataSource.length > 0) {
        return sourceInfo.dataSource;
      }
      if (sourceInfo.source !== undefined && sourceInfo.source.length > 0) {
        return sourceInfo.source;
      }
    }
    return fallbackSource;
  }

  private resolveSourceLabel(data: ToAppJson, fallbackSource: string): string {
    if (typeof data.source === 'string' && data.source.length > 0) {
      return data.source;
    }
    if (typeof data.source === 'object' && data.source !== null) {
      const sourceInfo = data.source as EegSourceJson;
      if (sourceInfo.source !== undefined && sourceInfo.source.length > 0) {
        return sourceInfo.source;
      }
      if (sourceInfo.input !== undefined && sourceInfo.input.length > 0) {
        return sourceInfo.input;
      }
    }
    return fallbackSource;
  }

  private resolveChannelStatusLabel(value: string | EegChannelStatusJson | undefined): string | undefined {
    if (typeof value === 'string') {
      return value;
    }
    if (typeof value !== 'object' || value === null) {
      return undefined;
    }

    if (value.summary !== undefined && value.summary.length > 0) {
      return value.summary;
    }
    if (value.state !== undefined && value.state.length > 0) {
      return value.state;
    }

    const ch1 = value.ch1 !== undefined && value.ch1.length > 0 ? value.ch1 : 'unknown';
    const ch2 = value.ch2 !== undefined && value.ch2.length > 0 ? value.ch2 : 'unknown';
    return `ch1:${ch1} ch2:${ch2}`;
  }

  private hasDisplayData(data: ToAppJson): boolean {
    return typeof data.focus === 'number'
      || typeof data.fatigue === 'number'
      || typeof data.relax === 'number'
      || typeof data.load === 'number'
      || (data.state !== undefined && data.state.length > 0)
      || (data.advice !== undefined && data.advice.length > 0);
  }
}

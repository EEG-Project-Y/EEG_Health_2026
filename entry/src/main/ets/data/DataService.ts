import { http } from '@kit.NetworkKit';
import fileIo from '@ohos.file.fs';
import defaultToAppJson from './ToApp.json';

const POLL_INTERVAL_MS: number = 1000;
const TO_APP_HTTP_ENDPOINT: string = 'http://127.0.0.1:18080/ToApp.json';
const TO_APP_RUNTIME_PATHS: string[] = [
  '/data/eeg_health/runtime/ToApp.json',
  '/data/eeg_health/runtime/currentData.json',
  '/data/eeg_health/runtime/lastData.json',
  '/data/app/el2/100/base/com.stitch.healthmonitor/haps/entry/files/ToApp.json'
];

type JsonNumber = number | string;

export interface ToAppJson {
  sequence?: number;
  timestamp?: number;
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
  mode?: string;
  direction?: string;
  advice?: string;
  local?: boolean;
  model?: string;
  summary?: string[];
}

interface ToAppPayload {
  sequence?: JsonNumber;
  timestamp?: JsonNumber;
  focus?: JsonNumber;
  fatigue?: JsonNumber;
  relax?: JsonNumber;
  load?: JsonNumber;
  quality?: JsonNumber;
  confidence?: JsonNumber;
  focusTrend?: JsonNumber;
  fatigueTrend?: JsonNumber;
  relaxTrend?: JsonNumber;
  loadTrend?: JsonNumber;
  state?: string;
  mode?: string;
  direction?: string;
  advice?: string;
  local?: boolean;
  model?: string;
  summary?: string[];
  data?: ToAppPayload;
}

export type ToAppJsonCallback = (data: ToAppJson) => void;

export class DataService {
  private timerId: number = -1;
  private filesDir: string = '';
  private hasDeliveredFrame: boolean = false;
  private pendingHttp: boolean = false;

  startReceiving(callback: ToAppJsonCallback, filesDir?: string): void {
    this.stopReceiving();
    this.filesDir = filesDir ?? this.filesDir;
    this.fetchToAppJson(callback);
    this.timerId = setInterval(() => {
      this.fetchToAppJson(callback);
    }, POLL_INTERVAL_MS);
  }

  stopReceiving(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private fetchToAppJson(callback: ToAppJsonCallback): void {
    this.fetchHttpToAppJson(callback);
  }

  private fetchHttpToAppJson(callback: ToAppJsonCallback): void {
    if (this.pendingHttp) {
      console.warn('[EEG_APP] http request still pending, fallback to file paths');
      this.fetchFileToAppJson(callback);
      return;
    }

    const request = http.createHttp();
    this.pendingHttp = true;
    try {
      request.request(
        TO_APP_HTTP_ENDPOINT,
        {
          method: http.RequestMethod.GET,
          connectTimeout: 800,
          readTimeout: 800
        },
        (error, data) => {
          this.pendingHttp = false;
          try {
            if (error) {
              console.error(`[EEG_APP] http read failed endpoint=${TO_APP_HTTP_ENDPOINT}, err=${JSON.stringify(error)}`);
              this.fetchFileToAppJson(callback);
              return;
            }

            const result = data.result;
            const raw: string = typeof result === 'string' ? result : JSON.stringify(result);
            if (this.deliverRawJson(raw, `http=${TO_APP_HTTP_ENDPOINT}`, callback)) {
              return;
            }
            this.fetchFileToAppJson(callback);
          } catch (parseError) {
            console.error(`[EEG_APP] http parse failed endpoint=${TO_APP_HTTP_ENDPOINT}, err=${JSON.stringify(parseError)}`);
            this.fetchFileToAppJson(callback);
          } finally {
            request.destroy();
          }
        }
      );
    } catch (requestError) {
      this.pendingHttp = false;
      console.error(`[EEG_APP] http request error endpoint=${TO_APP_HTTP_ENDPOINT}, err=${JSON.stringify(requestError)}`);
      request.destroy();
      this.fetchFileToAppJson(callback);
    }
  }

  private fetchFileToAppJson(callback: ToAppJsonCallback): void {
    const paths: string[] = this.buildRuntimePaths();
    for (let index = 0; index < paths.length; index++) {
      const path: string = paths[index];
      console.info(`[EEG_APP] reading path=${path}`);
      try {
        const raw: string = fileIo.readTextSync(path);
        if (raw.trim().length === 0) {
          console.warn(`[EEG_APP] empty json path=${path}`);
          continue;
        }
        if (this.deliverRawJson(raw, `path=${path}`, callback)) {
          return;
        }
      } catch (error) {
        console.error(`[EEG_APP] read failed path=${path}, err=${JSON.stringify(error)}`);
      }
    }

    if (!this.hasDeliveredFrame) {
      const fallback: ToAppJson = this.normalizeData(defaultToAppJson as ToAppPayload);
      this.hasDeliveredFrame = true;
      console.warn('[EEG_APP] all runtime json paths failed, use bundled ToApp.json');
      callback(fallback);
      return;
    }

    console.warn('[EEG_APP] all runtime json paths failed, keep previous frame');
  }

  private deliverRawJson(raw: string, source: string, callback: ToAppJsonCallback): boolean {
    if (raw.trim().length === 0) {
      console.warn(`[EEG_APP] empty json source=${source}`);
      return false;
    }

    try {
      const parsed: ToAppPayload = JSON.parse(raw) as ToAppPayload;
      const normalized: ToAppJson = this.normalizeData(parsed);
      this.hasDeliveredFrame = true;
      console.info(
        `[EEG_APP] parsed ${source}, sequence=${normalized.sequence}, focus=${normalized.focus}, ` +
          `fatigue=${normalized.fatigue}, relax=${normalized.relax}, load=${normalized.load}, ` +
          `quality=${normalized.quality}, confidence=${normalized.confidence}, state=${normalized.state}`
      );
      callback(normalized);
      return true;
    } catch (error) {
      console.error(`[EEG_APP] parse failed source=${source}, err=${JSON.stringify(error)}`);
      return false;
    }
  }

  private buildRuntimePaths(): string[] {
    const paths: string[] = [];
    if (this.filesDir.length > 0) {
      this.pushUniquePath(paths, this.filesDir + '/ToApp.json');
    }
    for (let index = 0; index < TO_APP_RUNTIME_PATHS.length; index++) {
      this.pushUniquePath(paths, TO_APP_RUNTIME_PATHS[index]);
    }
    return paths;
  }

  private pushUniquePath(paths: string[], path: string): void {
    for (let index = 0; index < paths.length; index++) {
      if (paths[index] === path) {
        return;
      }
    }
    paths.push(path);
  }

  private normalizeData(payload: ToAppPayload): ToAppJson {
    const body: ToAppPayload = payload.data ?? payload;
    const result: ToAppJson = {};

    result.sequence = this.toNumber(payload.sequence ?? body.sequence);
    result.timestamp = this.toNumber(payload.timestamp ?? body.timestamp);
    result.focus = this.toPercent(body.focus);
    result.fatigue = this.toPercent(body.fatigue);
    result.relax = this.toPercent(body.relax);
    result.load = this.toPercent(body.load);
    result.quality = this.toPercent(body.quality);
    result.confidence = this.toConfidencePercent(body.confidence ?? payload.confidence);
    result.focusTrend = this.toNumber(body.focusTrend ?? payload.focusTrend);
    result.fatigueTrend = this.toNumber(body.fatigueTrend ?? payload.fatigueTrend);
    result.relaxTrend = this.toNumber(body.relaxTrend ?? payload.relaxTrend);
    result.loadTrend = this.toNumber(body.loadTrend ?? payload.loadTrend);
    result.state = body.state ?? payload.state;
    result.mode = body.mode ?? payload.mode;
    result.direction = body.direction ?? payload.direction;
    result.advice = body.advice ?? payload.advice;
    result.local = body.local ?? payload.local;
    result.model = body.model ?? payload.model;
    result.summary = body.summary ?? payload.summary;

    return result;
  }

  private toNumber(value: JsonNumber | undefined): number | undefined {
    if (value === undefined) {
      return undefined;
    }
    const parsed: number = Number(value);
    if (Number.isNaN(parsed)) {
      return undefined;
    }
    return Math.round(parsed);
  }

  private toPercent(value: JsonNumber | undefined): number | undefined {
    const parsed: number | undefined = this.toNumber(value);
    if (parsed === undefined) {
      return undefined;
    }
    return Math.max(0, Math.min(100, parsed));
  }

  private toConfidencePercent(value: JsonNumber | undefined): number | undefined {
    if (value === undefined) {
      return undefined;
    }
    const parsed: number = Number(value);
    if (Number.isNaN(parsed)) {
      return undefined;
    }
    const percent: number = parsed >= 0 && parsed <= 1 ? parsed * 100 : parsed;
    return Math.max(0, Math.min(100, Math.round(percent)));
  }
}

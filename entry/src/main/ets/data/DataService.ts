import { http } from '@kit.NetworkKit';
import { AppConfig } from '../config/config';

export interface ToAppJson {
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
  direction?: string;
  advice?: string;
  local?: boolean;
  model?: string;
  summary?: string[];
}

export type ToAppJsonCallback = (data: ToAppJson) => void;

export class DataService {
  private timerId: number = -1;
  private readonly endpoint: string = `${AppConfig.backendUrl}/api/eeg`;

  startReceiving(callback: ToAppJsonCallback): void {
    this.stopReceiving();
    this.fetchToAppJson(callback);
    this.timerId = setInterval(() => {
      this.fetchToAppJson(callback);
    }, 2000);
  }

  stopReceiving(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private fetchToAppJson(callback: ToAppJsonCallback): void {
    const request = http.createHttp();
    try {
      request.request(
        this.endpoint,
        {
          method: http.RequestMethod.GET,
          connectTimeout: 5000,
          readTimeout: 5000
        },
        (error, data) => {
          try {
            if (error) {
              console.error(`DataService request failed: ${JSON.stringify(error)}`);
              return;
            }
            const result = data.result;
            const text = typeof result === 'string' ? result : JSON.stringify(result);
            const parsed = JSON.parse(text) as ToAppJson;
            callback(parsed);
          } catch (parseError) {
            console.error(`DataService parse failed: ${JSON.stringify(parseError)}`);
          } finally {
            request.destroy();
          }
        }
      );
    } catch (requestError) {
      console.error(`DataService request error: ${JSON.stringify(requestError)}`);
      request.destroy();
    }
  }
}

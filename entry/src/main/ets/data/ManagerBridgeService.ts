import { http } from '@kit.NetworkKit';
import { AppConfig } from '../config/config';

export interface ManagerBridgeStatus {
  success: boolean;
  state: string;
  sessionId: string;
  deviceId: string;
  openedAt: number;
  expiresAt: number;
  remainingSec: number;
  connectedManagerId: string;
  lastError: string;
  requestId?: string;
}

export class ManagerBridgeService {
  private static readonly VALID_STATES: string[] = [
    'CLOSED', 'OPENING', 'ADVERTISING', 'CONNECTED', 'TIMEOUT', 'ERROR'
  ];

  static open(durationSec: number = 300): Promise<ManagerBridgeStatus> {
    const safeDuration = Math.max(1, Math.min(300, Math.round(durationSec)));
    return ManagerBridgeService.request('/api/manager/bridge/open', http.RequestMethod.POST,
      JSON.stringify({ durationSec: safeDuration }));
  }

  static close(): Promise<ManagerBridgeStatus> {
    return ManagerBridgeService.request('/api/manager/bridge/close', http.RequestMethod.POST, '{}');
  }

  static status(): Promise<ManagerBridgeStatus> {
    return ManagerBridgeService.request('/api/manager/bridge/status', http.RequestMethod.GET);
  }

  private static async request(path: string, method: http.RequestMethod,
    body?: string): Promise<ManagerBridgeStatus> {
    const request = http.createHttp();
    try {
      const response = await request.request(AppConfig.managerBridgeBaseUrl + path, {
        method: method,
        header: {
          'Content-Type': 'application/json'
        },
        extraData: body,
        connectTimeout: 2000,
        readTimeout: 3000
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error('HTTP_' + response.responseCode.toString());
      }
      const raw = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
      return ManagerBridgeService.parse(raw);
    } finally {
      request.destroy();
    }
  }

  private static parse(raw: string): ManagerBridgeStatus {
    const data = JSON.parse(raw) as ManagerBridgeStatus;
    if (ManagerBridgeService.VALID_STATES.indexOf(data.state) < 0) {
      throw new Error('INVALID_BRIDGE_STATE');
    }
    data.success = data.success === true;
    data.sessionId = typeof data.sessionId === 'string' ? data.sessionId : '';
    data.deviceId = typeof data.deviceId === 'string' ? data.deviceId : '';
    data.connectedManagerId = typeof data.connectedManagerId === 'string' ? data.connectedManagerId : '';
    data.lastError = typeof data.lastError === 'string' ? data.lastError : '';
    data.openedAt = ManagerBridgeService.safeNumber(data.openedAt);
    data.expiresAt = ManagerBridgeService.safeNumber(data.expiresAt);
    data.remainingSec = Math.max(0, Math.round(ManagerBridgeService.safeNumber(data.remainingSec)));
    return data;
  }

  private static safeNumber(value: number): number {
    return typeof value === 'number' && value === value && value >= 0 ? value : 0;
  }
}

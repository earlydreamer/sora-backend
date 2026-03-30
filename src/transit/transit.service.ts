import {
  GatewayTimeoutException,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

interface EtaResult {
  etaMinutes: number;
  predictedArrivalAt: Date;
  isLate: boolean;
  safeDepatureAt: Date;
}

@Injectable()
export class TransitService {
  private readonly tmapApiKey: string;
  private readonly TIMEOUT_MS = 5_000;

  constructor(config: ConfigService) {
    this.tmapApiKey = config.get<string>('TMAP_API_KEY', '');
  }

  async getEta(
    origin: string,
    destination: string,
    targetArrivalTime: string,
    bufferMinutes: number,
  ): Promise<EtaResult> {
    if (!this.tmapApiKey) {
      throw new ServiceUnavailableException('TMAP API 키가 설정되지 않았습니다.');
    }

    const now = new Date();
    const etaMinutes = await this.fetchTmapEta(origin, destination);

    const predictedArrivalAt = new Date(now.getTime() + etaMinutes * 60_000);
    const targetMs = this.targetArrivalMs(now, targetArrivalTime);
    const isLate = predictedArrivalAt.getTime() > targetMs;

    // 안전 출발 시각 = 목표 도착 - eta - 버퍼
    const safeDepatureAt = new Date(
      targetMs - etaMinutes * 60_000 - bufferMinutes * 60_000,
    );

    return { etaMinutes, predictedArrivalAt, isLate, safeDepatureAt };
  }

  private async fetchTmapEta(origin: string, destination: string): Promise<number> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.TIMEOUT_MS);

    try {
      const url = new URL(
        'https://apis.openapi.sk.com/transit/routes',
      );
      const res = await fetch(url.toString(), {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          appKey: this.tmapApiKey,
        },
        body: JSON.stringify({
          startName: '출발지',
          startX: '',
          startY: '',
          endName: '도착지',
          endX: '',
          endY: '',
          reqCoordType: 'WGS84GEO',
          resCoordType: 'WGS84GEO',
          searchDttm: this.formatTmapDatetime(new Date()),
        }),
        signal: controller.signal,
      });

      if (!res.ok) {
        throw new ServiceUnavailableException('TMAP API 오류가 발생했습니다.');
      }

      const data = (await res.json()) as {
        metaData?: { plan?: { itineraries?: Array<{ totalTime?: number }> } };
      };
      const itineraries = data?.metaData?.plan?.itineraries;
      if (!itineraries?.length) {
        throw new ServiceUnavailableException('경로를 찾을 수 없습니다.');
      }

      return Math.ceil((itineraries[0].totalTime ?? 0) / 60);
    } catch (err: unknown) {
      if (err instanceof Error && err.name === 'AbortError') {
        throw new GatewayTimeoutException('TMAP API 응답 시간이 초과됐습니다.');
      }
      throw err;
    } finally {
      clearTimeout(timer);
    }
  }

  private targetArrivalMs(now: Date, targetArrivalTime: string): number {
    const [hh, mm] = targetArrivalTime.split(':').map(Number);
    const target = new Date(now);
    target.setHours(hh, mm, 0, 0);
    // 목표 시각이 이미 지났으면 내일로
    if (target.getTime() <= now.getTime()) {
      target.setDate(target.getDate() + 1);
    }
    return target.getTime();
  }

  private formatTmapDatetime(date: Date): string {
    return date
      .toISOString()
      .replace(/[-:T]/g, '')
      .substring(0, 12);
  }
}

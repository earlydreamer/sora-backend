import { Injectable } from '@nestjs/common';

@Injectable()
export class AppService {
  healthcheck(): { status: string } {
    return { status: 'ok' };
  }
}

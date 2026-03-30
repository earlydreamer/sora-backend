import { Controller, Get, Query, Request, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RoutesService } from '../routes/routes.service';
import type { RequestWithUser } from '../types/request-with-user';
import { TransitService } from './transit.service';

type Route = Awaited<ReturnType<RoutesService['findOne']>>;

@UseGuards(JwtAuthGuard)
@Controller('transit')
export class TransitController {
  constructor(
    private transit: TransitService,
    private routes: RoutesService,
  ) {}

  @Get('eta')
  async getEta(
    @Request() req: RequestWithUser,
    @Query('routeId') routeId?: string,
  ) {
    const userId = req.user.id;

    let route: Route;
    if (routeId) {
      route = await this.routes.findOne(routeId, userId);
    } else {
      const all = await this.routes.findAll(userId);
      route = all.find((r) => r.isDefault) ?? all[0];
    }

    const result = await this.transit.getEta(
      route.origin,
      route.destination,
      route.targetArrivalTime,
      route.bufferMinutes,
    );

    return {
      routeId: route.id,
      routeName: route.name,
      etaMinutes: result.etaMinutes,
      predictedArrivalAt: result.predictedArrivalAt,
      targetArrivalTime: route.targetArrivalTime,
      isLate: result.isLate,
      safeDepartureAt: result.safeDepartureAt,
      bufferMinutes: route.bufferMinutes,
    };
  }
}

import { Controller, Get, Query, Request, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RoutesService } from '../routes/routes.service';
import { TransitService } from './transit.service';

@UseGuards(JwtAuthGuard)
@Controller('transit')
export class TransitController {
  constructor(
    private transit: TransitService,
    private routes: RoutesService,
  ) {}

  @Get('eta')
  async getEta(@Request() req, @Query('routeId') routeId?: string) {
    const userId: string = req.user.id;

    let route;
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
      safeDepatureAt: result.safeDepatureAt,
      bufferMinutes: route.bufferMinutes,
    };
  }
}

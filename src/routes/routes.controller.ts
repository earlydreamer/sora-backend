import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
  Request,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import type { RequestWithUser } from '../types/request-with-user';
import { CreateRouteDto } from './dto/create-route.dto';
import { RoutesService } from './routes.service';

@UseGuards(JwtAuthGuard)
@Controller('routes')
export class RoutesController {
  constructor(private routes: RoutesService) {}

  @Get()
  findAll(@Request() req: RequestWithUser) {
    return this.routes.findAll(req.user.id);
  }

  @Post()
  create(@Request() req: RequestWithUser, @Body() dto: CreateRouteDto) {
    return this.routes.create(req.user.id, dto);
  }

  @Patch(':id')
  update(
    @Param('id') id: string,
    @Request() req: RequestWithUser,
    @Body() dto: Partial<CreateRouteDto>,
  ) {
    return this.routes.update(id, req.user.id, dto);
  }

  @Delete(':id')
  @HttpCode(204)
  remove(@Param('id') id: string, @Request() req: RequestWithUser) {
    return this.routes.remove(id, req.user.id);
  }
}

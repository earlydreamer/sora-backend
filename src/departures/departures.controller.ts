import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Request,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { DeparturesService } from './departures.service';
import { CreateDepartureDto } from './dto/create-departure.dto';
import { UpdateDepartureDto } from './dto/update-departure.dto';

@UseGuards(JwtAuthGuard)
@Controller('departures')
export class DeparturesController {
  constructor(private departures: DeparturesService) {}

  @Get()
  findAll(@Request() req, @Query('status') status?: string) {
    if (status === 'pending') {
      return this.departures.findPending(req.user.id);
    }
    return this.departures.findAll(req.user.id);
  }

  @Post()
  create(@Request() req, @Body() dto: CreateDepartureDto) {
    return this.departures.create(req.user.id, dto);
  }

  @Patch(':id')
  update(
    @Param('id') id: string,
    @Request() req,
    @Body() dto: UpdateDepartureDto,
  ) {
    return this.departures.update(id, req.user.id, dto);
  }
}

import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateRouteDto } from './dto/create-route.dto';

@Injectable()
export class RoutesService {
  constructor(private prisma: PrismaService) {}

  async findAll(userId: string) {
    return this.prisma.route.findMany({
      where: { userId },
      orderBy: [{ isDefault: 'desc' }, { createdAt: 'asc' }],
    });
  }

  async findOne(id: string, userId: string) {
    const route = await this.prisma.route.findUnique({ where: { id } });
    if (!route) throw new NotFoundException();
    if (route.userId !== userId) throw new ForbiddenException();
    return route;
  }

  async create(userId: string, dto: CreateRouteDto) {
    const count = await this.prisma.route.count({ where: { userId } });
    if (count >= 2) {
      throw new BadRequestException('경로는 최대 2개까지 등록할 수 있습니다.');
    }

    // 첫 경로는 자동으로 기본 경로
    const isDefault = count === 0 ? true : (dto.isDefault ?? false);

    if (isDefault) {
      await this.prisma.route.updateMany({
        where: { userId },
        data: { isDefault: false },
      });
    }

    return this.prisma.route.create({
      data: { ...dto, userId, isDefault, bufferMinutes: dto.bufferMinutes ?? 10 },
    });
  }

  async update(id: string, userId: string, dto: Partial<CreateRouteDto>) {
    await this.findOne(id, userId);

    if (dto.isDefault) {
      await this.prisma.route.updateMany({
        where: { userId },
        data: { isDefault: false },
      });
    }

    return this.prisma.route.update({ where: { id }, data: dto });
  }

  async remove(id: string, userId: string) {
    await this.findOne(id, userId);
    await this.prisma.route.delete({ where: { id } });
  }
}

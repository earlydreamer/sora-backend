import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateDepartureDto } from './dto/create-departure.dto';
import { UpdateDepartureDto } from './dto/update-departure.dto';

@Injectable()
export class DeparturesService {
  constructor(private prisma: PrismaService) {}

  async findAll(userId: string) {
    return this.prisma.departureRecord.findMany({
      where: { userId },
      include: { route: { select: { name: true } } },
      orderBy: { departedAt: 'desc' },
    });
  }

  // 미기록(actualLate가 null인) 세션 조회 — 앱 오픈 시 배너용
  async findPending(userId: string) {
    return this.prisma.departureRecord.findMany({
      where: { userId, actualLate: null },
      include: { route: { select: { name: true } } },
      orderBy: { departedAt: 'desc' },
    });
  }

  async create(userId: string, dto: CreateDepartureDto) {
    // routeId 소유권 확인
    const route = await this.prisma.route.findUnique({
      where: { id: dto.routeId },
    });
    if (!route) throw new NotFoundException('경로를 찾을 수 없습니다.');
    if (route.userId !== userId) throw new ForbiddenException();

    const [targetHH, targetMM] = route.targetArrivalTime.split(':').map(Number);
    const departedAt = new Date(dto.departedAt);
    const predictedArrivalAt = new Date(dto.predictedArrivalAt);
    const targetMs = new Date(departedAt);
    targetMs.setHours(targetHH, targetMM, 0, 0);

    const predictedLate = predictedArrivalAt.getTime() > targetMs.getTime();
    // predictedArrivalAt < departedAt인 비정상 입력 방어: 0 이하 방지
    const etaMinutes = Math.max(
      0,
      Math.ceil((predictedArrivalAt.getTime() - departedAt.getTime()) / 60_000),
    );

    return this.prisma.departureRecord.create({
      data: {
        userId,
        routeId: dto.routeId,
        departedAt,
        predictedArrivalAt,
        predictedLate,
        tmapEtaMinutes: etaMinutes,
      },
    });
  }

  async update(id: string, userId: string, dto: UpdateDepartureDto) {
    const record = await this.prisma.departureRecord.findUnique({
      where: { id },
    });
    if (!record) throw new NotFoundException();
    if (record.userId !== userId) throw new ForbiddenException();
    if (record.actualLate !== null) {
      throw new BadRequestException('이미 지각 여부가 기록된 출발입니다.');
    }

    return this.prisma.departureRecord.update({
      where: { id },
      data: { actualLate: dto.actualLate },
    });
  }
}

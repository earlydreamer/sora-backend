import { IsBoolean } from 'class-validator';

export class UpdateDepartureDto {
  @IsBoolean()
  actualLate: boolean;
}

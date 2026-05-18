import { Request, Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../types';
import * as settlementsService from './settlements.service';
import { sendSuccess, sendCreated } from '../../utils/response';
import { CreateSettlementInput } from '../../validations/settlement.validation';

export async function createSettlement(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authReq = req as AuthenticatedRequest;
    const settlement = await settlementsService.createSettlement(
      authReq.user.userId,
      req.body as CreateSettlementInput
    );
    sendCreated(res, settlement, 'Settlement recorded successfully');
  } catch (err) {
    next(err);
  }
}

export async function getGroupSettlements(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authReq = req as AuthenticatedRequest;
    const { id: groupId } = req.params;
    const settlements = await settlementsService.getGroupSettlements(
      groupId,
      authReq.user.userId
    );
    sendSuccess(res, settlements, 'Settlements retrieved');
  } catch (err) {
    next(err);
  }
}

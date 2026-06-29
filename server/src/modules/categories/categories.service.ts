import { NotFoundError, ForbiddenError } from '../../utils/app-error';
import * as repo from './categories.repository';
import { CreateCategoryInput, UpdateCategoryInput } from '../../validations/category.validation';

export async function createCategory(userId: string, input: CreateCategoryInput) {
  return repo.createCategory({
    userId,
    label: input.label,
    colorValue: input.colorValue,
    iconCodePoint: input.iconCodePoint,
  });
}

export async function getCategories(userId: string) {
  return repo.findAll(userId);
}

export async function updateCategory(userId: string, id: string, input: UpdateCategoryInput) {
  const cat = await repo.findById(id, userId);
  if (!cat) throw new NotFoundError('Category not found');
  if (cat.userId !== userId) throw new ForbiddenError('Not your category');

  return repo.updateCategory(id, {
    ...(input.label ? { label: input.label } : {}),
    ...(input.colorValue !== undefined ? { colorValue: input.colorValue } : {}),
    ...(input.iconCodePoint !== undefined ? { iconCodePoint: input.iconCodePoint } : {}),
  });
}

export async function deleteCategory(userId: string, id: string) {
  const cat = await repo.findById(id, userId);
  if (!cat) throw new NotFoundError('Category not found');
  if (cat.userId !== userId) throw new ForbiddenError('Not your category');

  await repo.softDelete(id);
}

import { Router } from 'express';
import { validate } from '../../middlewares/validate.middleware';
import { createCategorySchema, updateCategorySchema } from '../../validations/category.validation';
import * as controller from './categories.controller';

const router = Router();

router.get('/', controller.getCategories);
router.post('/', validate(createCategorySchema), controller.createCategory);
router.put('/:id', validate(updateCategorySchema), controller.updateCategory);
router.delete('/:id', controller.deleteCategory);

export default router;

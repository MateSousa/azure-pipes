resource "aws_ecr_repository" "this" {
  name                 = "${var.project_name}-${var.repository.name}"
  image_tag_mutability = var.repository.image_tag_mutability
  force_delete         = var.repository.force_delete

  encryption_configuration {
    encryption_type = var.repository.encryption.encryption_type
    kms_key         = var.repository.encryption.kms_key
  }

  image_scanning_configuration {
    scan_on_push = var.repository.image_scanning.scan_on_push
  }

  tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "this" {
  count      = var.lifecycle_policy != null ? 1 : 0
  repository = aws_ecr_repository.this.name
  policy     = var.lifecycle_policy
}

resource "aws_ecr_repository_policy" "this" {
  count      = var.repository_policy != null ? 1 : 0
  repository = aws_ecr_repository.this.name
  policy     = var.repository_policy
}

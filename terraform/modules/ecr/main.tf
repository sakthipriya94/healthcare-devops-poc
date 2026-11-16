locals {
  names = toset(["backend", "frontend", "nginx"])
}

# Repositories are shared by all environments (single account POC): the same
# immutable, SHA-tagged image is promoted dev -> staging -> prod.
resource "aws_ecr_repository" "this" {
  for_each             = var.create ? local.names : toset([])
  name                 = "${var.project}-${each.key}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the last ${var.keep_images} images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.keep_images
      }
      action = { type = "expire" }
    }]
  })
}

# When this stack does not own the repositories (staging/prod), look them up.
data "aws_ecr_repository" "existing" {
  for_each = var.create ? toset([]) : local.names
  name     = "${var.project}-${each.key}"
}

locals {
  created_urls  = { for k, r in aws_ecr_repository.this : k => r.repository_url }
  existing_urls = { for k, r in data.aws_ecr_repository.existing : k => r.repository_url }
  repos         = merge(local.created_urls, local.existing_urls) # exactly one of the two is non-empty

  created_arns  = [for k in sort(keys(aws_ecr_repository.this)) : aws_ecr_repository.this[k].arn]
  existing_arns = [for k in sort(keys(data.aws_ecr_repository.existing)) : data.aws_ecr_repository.existing[k].arn]
  arns          = concat(local.created_arns, local.existing_arns)
}

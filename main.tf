variable "github_organization_name" {
  type = string
}

variable "github_organization_description" {
  type    = string
  default = ""
}

variable "github_company_name" {
  type    = string
  default = ""
}

variable "github_billing_email" {
  type      = string
  sensitive = true
}

variable "github_repositories" {
  description = "Map of repositories to create"
  type = map(object({
    description     = string
    topics          = list(string)
    visibility      = string
    has_issues      = bool
    has_projects    = bool
    has_wiki        = bool
    has_downloads   = bool
    has_discussions = bool
  }))
}

resource "github_organization_settings" "main" {
  name          = var.github_organization_name
  description   = var.github_organization_description
  company       = var.github_company_name
  billing_email = sensitive(var.github_billing_email)

  has_organization_projects                                    = true
  has_repository_projects                                      = true
  default_repository_permission                                = "read"
  members_can_create_repositories                              = false
  members_can_create_internal_repositories                     = false
  members_can_create_pages                                     = false
  members_can_create_private_pages                             = false
  members_can_create_public_pages                              = false
  members_can_fork_private_repositories                        = false
  web_commit_signoff_required                                  = true
  advanced_security_enabled_for_new_repositories               = true
  dependabot_alerts_enabled_for_new_repositories               = true
  dependabot_security_updates_enabled_for_new_repositories     = true
  dependency_graph_enabled_for_new_repositories                = true
  secret_scanning_enabled_for_new_repositories                 = true
  secret_scanning_push_protection_enabled_for_new_repositories = true

  lifecycle {
    ignore_changes = [
      name,
      billing_email,

      # Not availale for free organizations
      members_can_create_repositories,
      advanced_security_enabled_for_new_repositories
    ]
  }
}

resource "github_repository" "repositories" {
  for_each = var.github_repositories

  name            = each.key
  description     = each.value.description
  topics          = each.value.topics
  visibility      = each.value.visibility
  has_issues      = each.value.has_issues
  has_projects    = each.value.has_projects
  has_wiki        = each.value.has_wiki
  has_downloads   = each.value.has_downloads
  has_discussions = each.value.has_discussions
  # Requires github provider 5.43+ and cannot upgrade due until https://github.com/integrations/terraform-provider-github/issues/2077 is fixed
  # web_commit_signoff_required = true
  allow_merge_commit     = false
  allow_rebase_merge     = false
  allow_squash_merge     = true
  allow_auto_merge       = true
  delete_branch_on_merge = true
  vulnerability_alerts   = true
  archive_on_destroy     = true

  security_and_analysis {

    # The provider doesn handle the free_tier correctly, as Github always implements advanced_security in public projects in all tiers, however only allows to enable it in paid tiers for private projects
    # In case you try to enable it in publci repos you get the following error: Error: PATCH https://api.github.com/repos/block-o/.github: 422 Advanced security is always available for public repos. []
    # dynamic "advanced_security" {
    #   for_each = each.value.visibility == "public" ? [] : [1]
    #   content {
    #     status = "enabled"
    #   }
    # }

    # feature only available for public repos in free tier
    secret_scanning {
      status = each.value.visibility == "public" ? "enabled" : "disabled"
    }

    # feature only available for public repos in free tier
    secret_scanning_push_protection {
      status = each.value.visibility == "public" ? "enabled" : "disabled"
    }
  }
}

resource "github_branch_protection" "main" {
  # feature only available for public repos in free tier
  for_each = {
    for k, v in github_repository.repositories : k => v
    if v.visibility == "public"
  }

  repository_id = each.value.node_id
  pattern       = "main"

  require_signed_commits          = true
  require_conversation_resolution = true
  allows_deletions                = false
  allows_force_pushes             = false

  required_status_checks {
    strict = true
  }

  required_pull_request_reviews {
    required_approving_review_count = 0
    dismiss_stale_reviews           = true
    require_code_owner_reviews      = true
  }

  enforce_admins = true
}

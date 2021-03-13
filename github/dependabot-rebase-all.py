#!/usr/bin/env python

import click
import github3


def dependabot_rebase_all(repository_name: str, token: str) -> None:
    """Tell Dependabot to rebase all its pull requests."""
    github = github3.login(token=token)
    owner, name = repository_name.split("/", 1)
    repository = github.repository(owner, name)
    for pull_request in repository.pull_requests(state="open"):
        if pull_request.user.login == "dependabot[bot]":
            pull_request.create_comment("@dependabot rebase\n")


@click.command()
@click.option(
    "--token",
    metavar="TOKEN",
    required=True,
    envvar="GITHUB_TOKEN",
    help="GitHub API token",
)
@click.argument("repository")
def main(token: str, repository: str) -> None:
    """Tell Dependabot to rebase all its pull requests."""

    try:
        dependabot_rebase_all(repository, token)
    except Exception as error:
        click.secho(f"error: {error}", fg="red")
        raise SystemExit(1)


if __name__ == "__main__":
    main(prog_name="dependabot-rebase-all")

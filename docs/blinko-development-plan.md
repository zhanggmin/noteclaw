# Blinko Development Plan

Source: https://blinko.apidocumentation.com/reference

The reference page embeds the Blinko TRPC OpenAPI 3.1.1 contract. The documented server URL is `/api`, so a user-provided instance root such as `https://example.com` maps to API URLs like `https://example.com/api/v1/note/list`.

## API Contract Summary

Authentication:
- `POST /v1/user/login`
- Request: `name`, `password`
- Response: user object with `token`
- App storage: save token as `api_key_blinko`, save normalized instance root as `secret_blinko_base_url`

Core note APIs:
- `POST /v1/note/list`: paged list with `page`, `size`, `orderBy`, `type`, `isArchived`, `isRecycle`, `searchText`, file/link/todo filters
- `POST /v1/note/detail`: note detail by `id`
- `POST /v1/note/upsert`: create or update note with `content`, `type`, optional `id`, state flags, attachments, references, metadata
- `POST /v1/note/batch-trash`: move notes to recycle bin by `ids`
- `POST /v1/note/batch-delete`: permanently delete notes by `ids`

Supporting APIs:
- `GET /v1/tags/list`: user tags
- `POST /v1/comment/list`, `POST /v1/comment/create`, `POST /v1/comment/update`, `POST /v1/comment/delete`
- `POST /api/file/upload`, `POST /api/file/upload-by-url`, `GET /api/file/{path}`
- Sharing, review, history, internal share, analytics, task, notification, follows, and public endpoints are documented but are not required for the first usable mobile note workflow.

## Development Phases

### Phase 1: Usable Authenticated Notes

Goal: make the Notes tab usable against a real Blinko instance.

Tasks:
- Normalize instance roots and consistently call `/api/v1/...`.
- Login with `name` and `password`, persist token and base URL.
- After login, return to the Notes tab and load notes.
- Replace demo data with `POST /v1/note/list`.
- Support pull-to-refresh, search submit, pagination, empty state, and error state.
- Parse documented note fields: `id`, `type`, `content`, `createdAt`, `updatedAt`, flags, tags, attachments, and `_count.comments`.

Acceptance:
- Fresh install opens login when no Blinko token exists.
- Successful login returns to the notes list.
- Notes list requests real data and renders note content, tags, attachment count, comment count, and updated time.

### Phase 2: Detail, Create, Edit, And Trash

Goal: support the common note lifecycle.

Tasks:
- Add API client methods for `detail`, `upsert`, `batch-trash`, `batch-delete`, and `tags/list`.
- Add a note detail screen that loads `POST /v1/note/detail`.
- Add create and edit flows using `POST /v1/note/upsert`.
- Add archive/top/trash affordances where the API supports state flags.
- Refresh list after successful mutation.

Acceptance:
- Tapping a note opens fresh detail data from the server.
- New note creation appears in the list after save.
- Editing a note updates server data and refreshes the list/detail.
- Trash operation removes a note from the default list.

### Phase 3: Comments, Attachments, And Tags

Goal: make note detail complete enough for daily use.

Tasks:
- Fetch and render comments with `POST /v1/comment/list`.
- Create/update/delete comments.
- Upload attachments and show attachment metadata.
- Use `GET /v1/tags/list` for tag filters and tag display.

Acceptance:
- Detail screen displays comments and attachments.
- Users can add comments.
- Users can filter notes by tag.

### Phase 4: Advanced Blinko Workflows

Goal: expose Blinko-specific collaboration and review features.

Tasks:
- Public and internal sharing flows.
- Daily review and random review lists.
- Note references and backlinks.
- History and version viewing.
- Analytics widgets.

Acceptance:
- Advanced actions match documented endpoint behavior and surface server errors clearly.

## Current Implementation Scope

This development pass implements Phase 1 and the core of Phase 2:
- API client methods for list, detail, upsert, trash/delete, and tags list.
- Login-to-list navigation.
- Real note list with search, pagination, refresh, and logout.
- Detail screen with server-loaded content.
- Create/edit note screen backed by `note/upsert`.
- Trash action from the detail screen with list refresh.

Remaining work after this pass:
- Comments, attachment upload/download, tag filters, share/review/history workflows, and deeper localization.

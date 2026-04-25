# Hosting Decision: PACTA + TRISK Bank Showcase Dashboard

> **Date:** 2026-04-26
> **Decision:** Streamlit Community Cloud (free tier)
> **Custom subdomain:** `pactavn.streamlit.app`

## Decision Matrix

| Criteria | Streamlit Community Cloud | Hugging Face Spaces (Streamlit) | Supabase + Vercel | Firebase + Cloud Run | Oracle Cloud Free VM | GitHub Pages / Netlify (static) |
|---|---|---|---|---|---|---|
| **Card required** | No | No | No (Supabase free + Vercel Hobby) | Yes (card on file) | Yes (card on file) | No |
| **Sleep behavior** | Idle after ~15 min; cold start ~10s | Idle after ~48h; cold start ~15s | Always on (Vercel) + Supabase | Always on (CF) | Always on | Always on |
| **RAM / CPU** | ~1 GB | ~2 GB (16 GB on T4 GPU) | 512 MB (SB) + 1 GB (Vercel) | 256 MB (CF min) | 4 ARM cores, 24 GB | N/A (static) |
| **File-size limit** | 1 GB repo | 10 GB repo | 2 MB (Vercel function) | 10 MB (CF response) | Disk | None practical |
| **Custom domain** | Yes (CNAME, free tier supports) | Yes (CNAME) | Yes (Vercel) | Yes (Firebase) | Yes (your IP) | Yes |
| **Static CSV/PNG hosting** | Via repo + `pandas.read_csv` | Via repo | Via Supabase Storage + API | Via Firebase Storage + CDN | Via nginx | Direct |
| **Secrets / env vars** | `st.secrets` | HF Spaces secrets | Vercel env vars | Firebase secrets | env file | None |
| **Build effort** | 1-2 days | 1-2 days | 3-5 days | 4-6 days | 3-5 days | 0.5 days |

## Recommendation: Streamlit Community Cloud

### Rationale
1. **No credit card required** — deploy with only a GitHub account
2. **GitHub-linked** — push `dashboard/` to repo, Streamlit auto-deploys
3. **Sufficient RAM** (~1 GB) for reading CSVs + rendering Plotly charts
4. **Custom subdomain** `pactavn.streamlit.app` is free and instant
5. **Secrets manager** for optional future password, API keys
6. **Minimal build effort** — pure Python, no Docker, no Postgres, no REST API

### Constraints
- Idle sleep after ~15 min of inactivity → cold start ~10s. **Mitigation:** warm URL 2 min before live demo
- 1 GB RAM limit → keep artifact bundle ≤100 MB; no live R kernel
- File size through Streamlit must be via repo (files deployed with `dashboard/data/`)

## Fallback: Hugging Face Spaces

If Streamlit Community Cloud changes free-tier terms or the app exceeds 1 GB RAM in practice:
1. Create a Space at `huggingface.co/spaces/pacta-trisk-vn/dashboard`
2. Use Streamlit SDK (same `dashboard/` codebase, same `requirements.txt`)
3. Custom domain available via CNAME

## Rejected Alternatives

| Alternative | Reason for rejection |
|---|---|
| **Supabase + Vercel** | ~3x build effort, requires schema migration of CSVs into Postgres, separate Next.js frontend hosting. Unnecessary for a read-only demo. |
| **Firebase + Cloud Run** | Credit card required at signup. Operational overhead (Docker container, IAM) too high for a single demo. |
| **Oracle Cloud Always Free** | 24 GB RAM, always-on, but: card required, self-managed Linux VM (TLS, reverse proxy, systemd), frequent free-tier reclamation. |
| **Pure static (GitHub Pages / Netlify)** | Cheapest and simplest, but loses interactivity (filters, sensitivity sliders, downloadable subsets). Bank showcase is materially better with interaction. |

## Decision Record

| Field | Value |
|---|---|
| **Chosen platform** | Streamlit Community Cloud |
| **Subdomain** | `pactavn.streamlit.app` |
| **Auth** | None (fully public) |
| **Data backend** | CSV/PNG files in `dashboard/data/` deployed with repo |
| **Language** | Python (Streamlit + Plotly + Pandas) |
| **Fallback** | Hugging Face Spaces (Streamlit SDK) |
| **Decision date** | 2026-04-26 |

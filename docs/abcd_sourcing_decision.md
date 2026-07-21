# ABCD Sourcing Decision Brief

> Asset-based company data (ABCD) is the non-loanbook input that makes PACTA and TRISK work. This brief frames the sourcing decision for a real Vietnam bank engagement.

## The Problem

PACTA matches loans to physical assets (power plants, cement kilns, steel mills, vehicle production lines). TRISK then prices transition risk on those assets. The synthetic `data/vietnam_abcd.csv` used in this demo is **MCB-shaped**: it covers exactly the companies and sectors in the Mekong Commercial Bank loanbook, not the full Vietnamese economy. A real bank will have a different loanbook, so its ABCD must be built or licensed to cover its actual counterparties.

## Option A: License Asset Impact (or equivalent commercial ABCD)

**What it is:** A commercial asset-level database that maps companies to physical assets, production, capacity, and emission factors.

**Vietnam coverage assessment (publicly available information only):**

| Sector | Coverage | Notes |
|---|---|---|
| Power | Strong | Most grid-scale plants and many IPPs are tracked globally |
| Automotive | Strong | OEM assembly lines and market share data are well covered |
| Cement | Partial | Major producers (VICEM, Holcim/international majors) covered; smaller local plants may be missing |
| Steel | Partial | Integrated mills (Hoa Phat) usually covered; mini-mills and EAF operators sparser |
| Coal mining | Weak | Mine-level production data is sparse for Vietnam |

**Cost:** To be confirmed with vendor. Typical commercial ABCD licenses are priced by sector coverage, company count, and update frequency.

**Lead time:** Typically 4–8 weeks for procurement, legal review, and data delivery.

**Best for:** Banks that need broad coverage quickly and have budget for a recurring license.

## Option B: Self-Collect ABCD

**What it is:** Build the asset database from public disclosures, regulatory filings, and third-party trackers.

**Vietnam-specific sources:**

| Sector | Likely Sources | Effort |
|---|---|---|
| Power | EVN/GENCO annual reports, PDP8 project lists, Global Energy Monitor plant trackers | High (many plants, mixed disclosure quality) |
| Automotive | Company annual reports, Vietnam Automobile Manufacturers Association (VAMA) statistics | Medium |
| Cement | VICEM and Holcim sustainability reports, Ministry of Construction capacity data | Medium |
| Steel | Hoa Phat, Pomina, VNSTEEL disclosures, World Steel Association data | Medium |
| Coal | Vinacomin annual reports, Ministry of Industry and Trade production statistics | Medium-High |

**Licensing/attribution constraints:** Global Energy Monitor data is often CC-BY or similar; verify before commercial use. Company disclosures are generally usable for internal analysis but may restrict redistribution.

**Best for:** Banks with strong in-house ESG/data teams, or engagements focused on a small number of known counterparties.

## Option C: Hybrid (Recommended Default)

**What it is:** License commercial ABCD for power and automotive (best coverage, fastest time-to-value), and self-build for cement and steel (where the loanbook is smaller and public disclosures are sufficient).

**Why this is the default recommendation:**

- Power and automotive are the largest, most data-rich sectors in a typical Vietnam bank book.
- Cement and steel are often smaller exposures; the cost of full commercial coverage may exceed the value.
- A hybrid approach lets the bank start the alignment analysis in weeks while the self-build layers are populated in parallel.

**Exception:** If the engagement is **power-only**, a single-sector commercial license is usually the cleanest path.

## Decision Trigger

> **Decide before signing the data-phase start date in any real proposal.**

The ABCD choice affects:

- Project timeline (license procurement vs. build effort)
- Budget (license fees vs. staff time)
- Coverage quality (completeness of physical-asset mapping)
- Update cadence (quarterly vendor refresh vs. manual maintenance)

## Sourcing Checklist for a Real Engagement

1. [ ] Finalize the bank's loanbook sector and counterparty list
2. [ ] Map each counterparty to the ABCD coverage options above
3. [ ] Request vendor coverage sample for the top 20 counterparties
4. [ ] Confirm license terms (redistribution, attribution, update frequency)
5. [ ] Decide hybrid split and document in the engagement config / data contract
6. [ ] Establish a quarterly ABCD refresh process

## Relation to This Demo

All ABCD data in this repository is synthetic and illustrative. The `data/vietnam_abcd.csv` file demonstrates the **shape** of the data a real engagement needs (columns, units, sector/technology mapping), but it is not a real asset database. The intake schema in `intake/SCHEMA.md` and the template in `intake/templates/abcd_template.csv` define the contract a real ABCD file must satisfy.

---

*Decision owner: engagement lead / data lead. Review date: before any real-data phase kickoff.*

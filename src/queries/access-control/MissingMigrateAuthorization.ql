/**
 * @name Missing authorization in migrate handler
 * @description Migrate handler does not verify admin/governance authorization.
 *              Unauthorized migration allows complete contract takeover.
 * @kind problem
 * @id cosmwasm/missing-migrate-authorization
 * @problem.severity error
 * @precision high
 * @tags security
 *       external/cwe/cwe-862
 */

import rust
import src.lib.CosmWasm

from MigrateHandler migrate
where
  not hasAuthorizationCheck(migrate) and
  isUserContractCode(migrate.getLocation().getFile()) and
  not isInTestModule(migrate)
select migrate,
  "Migrate handler lacks admin authorization check. Unauthorized migration enables full contract takeover."

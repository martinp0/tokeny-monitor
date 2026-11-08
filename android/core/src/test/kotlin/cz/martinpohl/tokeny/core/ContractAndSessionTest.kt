package cz.martinpohl.tokeny.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ContractAndSessionTest {
    @Test
    fun usageSummaryUrlEncodesTheTimeZoneAndStaysOnTheWebOrigin() {
        assertEquals(
            "https://tokeny.martinpohl.cz/api/usage-summary?tz=Europe%2FPrague",
            TokenyApiContract.usageSummaryUrl("Europe/Prague"),
        )
        assertEquals(
            "https://tokeny.martinpohl.cz/api/usage-summary?tz=Europe%2FPrague",
            TokenyApiContract.usageSummaryUrl("  "),
        )
    }

    @Test
    fun everyCredentialShapeIsRejected() {
        assertEquals(CredentialRejection.BLANK, rejectCredential("  "))
        assertEquals(
            CredentialRejection.COOKIE_SHAPED,
            rejectCredential("__Secure-neon-auth.session_token=abc.def"),
        )
        assertEquals(CredentialRejection.COOKIE_SHAPED, rejectCredential("Cookie: neon-auth=1"))
        assertEquals(CredentialRejection.PROVIDER_KEY, rejectCredential("sk-ant-api03-secret"))
        assertEquals(CredentialRejection.PROVIDER_KEY, rejectCredential("sk_live_secret"))
        assertEquals(CredentialRejection.PROVIDER_KEY, rejectCredential("or-v1-secret"))
        val orm = "orm_" + "ab".repeat(32)
        assertEquals(CredentialRejection.PERSONAL_MCP_TOKEN, rejectCredential(orm))
        assertEquals(
            CredentialRejection.JWT_NEEDS_A_SESSION_FLOW,
            rejectCredential("eyJhbGciOiJFZERTQSJ9.eyJzdWIiOiJ1c2VyIn0.sig"),
        )
        assertEquals(CredentialRejection.UNRECOGNIZED, rejectCredential("hello"))
    }

    @Test
    fun capturedAnonymousSummaryIsUnauthorizedAndProRequiredStaysDistinct() {
        val captured = """{"error":"Unauthorized"}"""
        assertEquals(SummaryFailure.UNAUTHORIZED, classifySummaryStatus(401, captured)!!.failure)
        val pro = """{"error":"pro_required","feature":"budget","message":"Tato funkce vyžaduje Tokeny Pro."}"""
        assertEquals(SummaryFailure.PRO_REQUIRED, classifySummaryStatus(403, pro)!!.failure)
        assertEquals(SummaryFailure.FORBIDDEN, classifySummaryStatus(403, """{"error":"nope"}""")!!.failure)
        assertEquals(SummaryFailure.NOT_DEPLOYED, classifySummaryStatus(404, "")!!.failure)
        assertEquals(SummaryFailure.SERVER, classifySummaryStatus(500, "")!!.failure)
        assertNull(classifySummaryStatus(200, "{}"))
    }

    @Test
    fun demoFlowNeverBecomesAPrivateSession() {
        val model = SpendModel()
        assertFalse(showsSampleBanner(model.state.phase))
        model.openAuthGap()
        assertTrue(model.state.phase is Phase.AuthGap)
        model.closeAuthGap()

        val generation = model.requestDemo(DemoVariant.PRO)
        assertTrue(showsSampleBanner(model.state.phase))
        assertTrue(model.state.phase is Phase.Loading)
        model.fail(generation)
        assertTrue(model.state.phase is Phase.Failed)
        assertTrue(showsSampleBanner(model.state.phase))

        val again = model.requestDemo(DemoVariant.FREE)
        val summary = DemoCatalog().load(DemoVariant.FREE)
        model.succeed(generation, summary)
        assertTrue(model.state.phase is Phase.Loading)
        model.succeed(again, summary)
        val ready = model.state.phase as Phase.Ready
        assertEquals(DemoVariant.FREE, ready.variant)
        assertEquals(UsageSummary.Plan.FREE, ready.summary.plan)

        model.select(Destination.BUDGET)
        assertEquals(Destination.BUDGET, model.state.destination)
        model.setCurrency(Currency.USD)
        model.setOffline(true)
        model.closeSample()
        assertTrue(model.state.phase is Phase.SignedOut)
        assertEquals(Currency.USD, model.state.currency)
        assertTrue(model.state.offline)
        assertEquals(Destination.OVERVIEW, model.state.destination)
        model.succeed(again, summary)
        assertTrue(model.state.phase is Phase.SignedOut)
    }

    @Test
    fun authGapDoesNotInterruptAnOpenSample() {
        val model = SpendModel()
        val generation = model.requestDemo(DemoVariant.EMPTY)
        model.succeed(generation, model.load(DemoVariant.EMPTY))
        model.openAuthGap()
        assertTrue(model.state.phase is Phase.Ready)
    }
}

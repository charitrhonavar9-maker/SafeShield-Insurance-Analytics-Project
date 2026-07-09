-- Query 1 – Executive Management Request
-- Business Problem
-- The CFO has observed that claim payouts have increased significantly, but doesn't know which insurance products are responsible.
-- Before making pricing or underwriting decisions, management wants to identify the policy types contributing the highest claim payouts.

-- Business Requirement
-- Calculate the total approved claim payout for each policy type.

SELECT pt. PolicyTypeName, count(DISTINCT c.ClaimID) as Total_Claims,
sum(ClaimAmount) as Total_Claim_Amount, sum(ApprovedAmount) as Total_approved_amount,
sum(paymentamount) as Total_payment,
ROUND(AVG(ClaimAmount), 2 ) as AVG_Claim_Amount, ROUND(avg(Approvedamount), 2 ) as AVG_Approved_Amount
FROM policies p
JOIN policy_type pt
ON pt.PolicyTypeID = p.PolicyTypeID                                    
JOIN claims c ON p.policyid = c.policyid
LEFT JOIN claims_assessments ca ON c.ClaimID = ca.ClaimID
LEFT JOIN payments pa ON c.ClaimID = pa.ClaimID
GROUP BY pt. PolicyTypeName
ORDER BY Total_payment DESC;



-- Query 2 – Loss Ratio Analysis by Policy Type
-- Business Scenario
-- The CFO asks:
-- "We are collecting premiums from customers, but are we actually making money? Which insurance products are profitable and which are causing losses?"

WIth policypremium as 
(
SELECT PolicyTypeID, sum(PremiumAmount) as True_premium
FROM policies p
GROUP BY PolicyTypeID
),

claimspayment as 
(
SELECT c.PolicyID, sum(paymentamount) as True_payment
FROM claims c
JOIN payments pa
ON c.ClaimID = pa.ClaimID
GROUP BY c.PolicyID
),
totalpaymentspertype as 
(
SELECT p.PolicyTypeID, sum(cp.True_payment) as T_payment
FROM policies p
JOIN claimspayment cp ON p.PolicyID = cp.PolicyID
GROUP BY p.PolicyTypeID
)
SELECT pt.PolicyTypeName, coalesce(pp.True_premium, 0) as Total_premium,
coalesce(tp.T_payment, 0) as Total_payment,
round((coalesce(tp.T_payment,0) / coalesce( pp.True_premium, 0 ) ) * 100, 2 ) as Loss_ratio,
round(coalesce(pp.True_premium, 0 ) - coalesce(tp.T_payment, 0 ), 2) as profit
FROM policy_type pt
LEFT JOIN policypremium pp
ON pp.PolicyTypeID = pt.PolicyTypeID
LEFT JOIN totalpaymentspertype tp
ON pt.PolicyTypeID = tp.PolicyTypeID
ORDER BY Loss_ratio DESC;



-- Query 3: Branch Performance Analysis & Ranking
-- Business Scenario
-- The CEO asks:
-- "Which branches are performing well, and which branches require immediate management attention?"

with branchearning as 
(
SELECT Branchname, b.BranchID, state, count(p.PolicyID) as Total_policies,sum(premiumamount) as Total_premium
FROM policies p
JOIN branches b
ON p.BranchID = b.BranchID
GROUP BY Branchname, b.BranchID, state
),
paymentdetails as 
(
SELECT p.BranchID, COUNT(c.ClaimID) as TotalClaims, sum(PaymentAmount) as Total_payment
FROM policies p
JOIN claims c
ON p.PolicyID = c.PolicyID
JOIN payments pa
ON c.ClaimID = pa.ClaimID
GROUP BY p.BranchID
)
SELECT be.BranchID, Branchname, State, coalesce(pd.Total_payment,0) as Total_payment,
coalesce(be.Total_premium, 0) as Total_premium,
ROUND( Coalesce ( pd.Total_payment, 0 ) / Nullif( be.Total_premium , 0 ) * 100 , 2 ) as Loss_ratio,
DENSE_RANK() OVER (ORDER BY Coalesce ( pd.Total_payment, 0 ) / Nullif( be.Total_premium , 0 )  DESC ) as Branchrank
FROM paymentdetails pd
LEFT JOIN branchearning be
ON pd.BranchID = be.BranchID
ORDER BY Branchrank;



-- Query 4 – Fraud Risk Analysis
-- Department
-- 🛡️ Fraud Investigation Team
-- Business Scenario
-- The Head of Fraud Analytics says:
-- "We suspect that some branches have unusually high fraud activity. We need to identify which branches require investigation."--

WITh branchdetails as 
(
SELECT b.BranchID, BranchName, State, count(c.ClaimID) as TotalClaims
FROM Branches b
jOIN policies p
ON b.BranchID = p.BranchID
JOIN claims c
ON c.PolicyID = p.PolicyID
GROUP BY b.BranchID, BranchName, State
),

fraud_details as 
(
SELECT p.BranchID, count(DISTINCT CASE WHEN Fraudflag = 'Yes' Then c.ClaimID END ) as TotalFruad,
sum(Case WHEN fraudflag = 'Yes' THEN ca.approvedamount ELSE 0 END ) as TotalFraudAmount
FROM fraud_investigations f
JOIN claims c ON f.ClaimID = c.ClaimID
JOIN policies p ON p.PolicyID = c.PolicyID
JOIN claims_assessments ca ON c.ClaimID = ca.ClaimID
GROUP BY p.BranchID
)
SELECT bd.BranchID, bd.BranchName, State,bd.TotalClaims,round(fd.TotalFraudAmount,2) as Fraud_amount, fd.TotalFruad, round((coalesce(fd.TotalFruad,0 ) / coalesce(bd.TotalClaims,0)) *100,2) as Fraud_ratio,
DENSE_RANK() OVER (ORDER BY coalesce(fd.TotalFruad,0 ) / coalesce(bd.TotalClaims,0)  DESC ) as Fraud_rank
FROM branchdetails bd
LEFT JOIN fraud_details fd
ON bd.BranchID = fd.BranchID
ORDER BY Fraud_ratio DESC;


-- Query 5 – Claim Settlement Efficiency Analysis
-- Department
-- 📋 Claims Operations Team
-- Business Scenario
-- The Claims Head asks:
-- "Which policy types take the longest to settle claims? Are we meeting our SLA (Service Level Agreement)?"

with claimsdetails as 
(
SELECT PolicyTypeName, c.ClaimID, datediff(str_to_date(Assessmentdate, '%Y-%m-%d'), str_to_date(ClaimDate, '%Y-%m-%d')) as Settlementdays
FROM policy_type pt
JOIN policies p ON pt.PolicyTypeID = p.PolicyTypeID
JOIN claims c ON c.PolicyID = p.PolicyID
JOIN claims_assessments ca ON ca.ClaimID = c.ClaimID
WHERE Assessmentstatus = 'Approved'
)

SELECT PolicyTypeName, count(ClaimID) as TotalClaims, Max(Settlementdays) as Slowest_settlement, min(Settlementdays) as Fatsest_settlement,
round(AVG(Settlementdays),2) as Avg_days, sum( case when settlementdays <= 15 THEN 1 ELSE 0 END ) as ClaimswithSLA,
round((sum( case when settlementdays <= 15 THEN 1 ELSE 0 END ) / count(ClaimID) ) *100, 2) as SLA_percent, 
DENSE_RANK() OVER (ORDER BY AVG(Settlementdays)) as rnk
from claimsdetails
GROUP BY PolicyTypeName
ORDER BY rnk;



-- Query 6 – Customer Claim Behaviour Analysis
-- Department
-- 👥 Customer Relationship Management (CRM)
-- Business Scenario
-- The Head of Customer Experience asks:
-- "Which customers file claims frequently, how much have they claimed, and should they be considered high-risk customers?"

 

with customerdetails as 
(
SELECT cu.CustomerID, CustomerName, State, count(c.ClaimID) as TotalClaims, sum(ClaimAmount) as TotalclaimAmount,
sum( CASE WHEN assessmentstatus = 'Approved' THEN approvedamount ELSE 0 END ) as TotalApprovedAmount
FROM customers cu
JOIN policies p ON cu.CustomerID = p.CustomerID
LEFT JOIN claims c ON p.PolicyID = c.PolicyID
LEFT JOIN claims_assessments ca ON c.ClaimID = ca.ClaimID
GROUP BY cu.CustomerID, CustomerName, State
)
SELECT CustomerID, CustomerName, State,TotalClaims, TotalclaimAmount, TotalApprovedAmount, round(((TotalApprovedAmount) / nullif(TotalclaimAmount,0))  * 100 , 2 ) as approval_rate,
DENSE_RANK() OVER ( ORDER BY TotalclaimAmount DESC ) as rnk, 
Case when totalclaims > 15 or TotalApprovedAmount > 100000 Then 'High Risk'
WHEN totalclaims between 5 and 15 THEN 'Medium Risk' ELSE 'Low Risk' END as Category
FROM customerdetails
oRDER BY rnk;




-- Query 7 – Monthly Claim Trend & Business Growth Analysis
-- Department
-- 📈 Executive Dashboard / Business Intelligence Team
-- Business Scenario
-- The CEO asks:
-- "How has our claims business changed month by month? Which months had unusually high claim amounts? Are claims increasing faster than premiums?"


WITH monthlydata as 
(
SELECT Year(str_to_date(ClaimDate, '%y-%m-%d')) as Claimyear,
MonthName(str_to_date(ClaimDate, '%y-%m-%d')) as ClaimMonth, Month(str_to_date(ClaimDate, '%y-%m-%d')) as MonthNumber, count(c.ClaimID) as TotalClaims, 
sum(Claimamount) as TotalClaimAmount, sum( CASE WHEN assessmentstatus = 'Approved' Then ApprovedAmount ELSE 0 END ) as TotalApprovedAmount, sum(PremiumAmount) as Total_Premium, 
rOUND(avg(ClaimAmount),2) as AVG_Claim_Amount
from claims c
JOIN policies p ON c.PolicyID = p.PolicyID
LEFT JOIN claims_assessments ca ON c.ClaimID = ca.ClaimID
GROUP BY Year(str_to_date(ClaimDate, '%y-%m-%d')), Month(str_to_date(ClaimDate, '%y-%m-%d')),MonthName(str_to_date(ClaimDate, '%y-%m-%d')) 
)
SELECT ClaimYear, MonthNumber,ClaimMonth,TotalClaims, AVG_Claim_Amount, round(TotalClaimAmount, 2) as TotalClaimAmount, round(TotalApprovedAmount, 2)  as TotalApprovedAmount,
round( (coalesce(TotalApprovedAmount, 0 ) / nullif(TotalClaimAmount, 0 ) ) * 100 , 2) as Approval_rate, Lag(TotalClaimAmount) OVER( ORDER BY ClaimYear, MonthNumber ) as PreviousClaimAmount,
round( (TotalClaimAmount - Lag(TotalClaimAmount) OVER( ORDER BY ClaimYear, MonthNumber )) / nullif (Lag(TotalClaimAmount) OVER( ORDER BY ClaimYear, MonthNumber ) , 0)  * 100, 2 ) as Growth_rate,
DENSE_RANK() OVER ( PARTITION BY ClaimYear ORDER BY TotalClaimAmount DESC ) as ClaimRank
FROM monthlydata
ORDER BY ClaimYear, MonthNumber,ClaimMonth;




-- Query 8 – Customer Retention & Renewal Analysis
-- Department
-- 📊 CRM / Customer Success / Sales
-- Business Scenario
-- The Head of Customer Retention asks:
-- "Which customers are loyal to the company, who is likely to churn, and what is our renewal performance?"

WITH CustomerDetails as 
(
SELECT cu.CustomerID,CustomerName, State, STR_TO_DATE(Customersince, '%d-%m-%Y') as Customersinces, count(PolicyID) as Totalpolicies,
round(sum(premiumamount),2) as Total_Premium,
max(str_to_date(Policyenddate, '%Y-%m-%d')) as LastEndDate
FROM customers cu
LEFT JOIN policies p
ON cu.CustomerID = p.CustomerID
GROUP BY cu.CustomerID,CustomerName, State, STR_TO_DATE(Customersince, '%d-%m-%Y')
)
SELECT CustomerID, CustomerName, State, Timestampdiff( YEAR, Customersinces, curdate() ) as "Customer_Tenure(Years)",
datediff(LastEndDate,curDate()) as Days_left, case when datediff(LastEndDate,curDate()) > 30 THEN 'Active' 
WHEN datediff(LastEndDate,curDate()) between 0 AND 30 THEN 'Due soon' ELSE 'Expired' END as RenewalStatus,
CASE WHEN Total_Premium > 100000 THEN 'Platinum' WHEN Total_Premium BETWEEN 50000 AND 100000 THEN 'Gold'
ELSE 'Silver' END as Category
FROM CustomerDetails
ORDER BY CustomerID, CustomerName, State;


-- Query 9 – Claims Adjuster Performance Dashboard
-- Business Scenario
-- The Head of Claims asks:

-- "We have 150 claim adjusters. Some approve claims very quickly, some reject too many claims, 
-- and some are handling a much higher workload. I want to evaluate every adjuster's performance."

WITH AdjusterPerformance AS
(
    SELECT ca.Assessor, COUNT(DISTINCT c.ClaimID) AS TotalClaimsHandled,
    ROUND(SUM(ca.ApprovedAmount),2) AS TotalApprovedAmount,
	ROUND(AVG(ca.ApprovedAmount),2) AS AvgApprovedAmount,
    SUM(CASE
                WHEN ca.AssessmentStatus='Approved'
                THEN 1
                ELSE 0
            END) AS ApprovedClaims,
	SUM(CASE
                WHEN ca.AssessmentStatus='Rejected'
                THEN 1
                ELSE 0
            END) AS RejectedClaims,
	SUM(CASE
                WHEN ca.FraudFlag='Yes'
                THEN 1
                ELSE 0
            END) AS FraudCasesHandled,
	ROUND(
            AVG(
                DATEDIFF(
                    STR_TO_DATE(ca.AssessmentDate,'%Y-%m-%d'),
                    STR_TO_DATE(c.ClaimDate,'%Y-%m-%d')
                )
            ),
        2) AS AvgSettlementDays

    FROM claims_assessments ca

    JOIN Claims c
        ON ca.ClaimID = c.ClaimID

    GROUP BY ca.Assessor
)

SELECT

    Assessor,

    TotalClaimsHandled,

    TotalApprovedAmount,

    AvgApprovedAmount,

    ROUND(
        (ApprovedClaims / NULLIF(TotalClaimsHandled,0))*100,
        2
    ) AS ApprovalRate,

    ROUND(
        (RejectedClaims / NULLIF(TotalClaimsHandled,0))*100,
        2
    ) AS RejectionRate,

    FraudCasesHandled,

    AvgSettlementDays,

    CASE
        WHEN TotalClaimsHandled > 500 THEN 'High'
        WHEN TotalClaimsHandled BETWEEN 250 AND 500 THEN 'Medium'
        ELSE 'Low'
    END AS Workload,

    DENSE_RANK() OVER
    (
        ORDER BY
            (ApprovedClaims / NULLIF(TotalClaimsHandled,0)) DESC,
            AvgSettlementDays ASC,
            FraudCasesHandled DESC
    ) AS PerformanceRank

FROM AdjusterPerformance

ORDER BY PerformanceRank;



-- Query 10 – Agent Performance & Portfolio Profitability Analysis
-- Business Problem

-- Management wants to identify the best-performing insurance agents based on business generated, claim payouts, profitability, customer acquisition, and fraud cases.

WITH AgentPerformance AS
(
    SELECT

        a.AgentID,
        a.AgentName,
        b.BranchName,

        COUNT(DISTINCT p.CustomerID) AS TotalCustomers,

        COUNT(DISTINCT p.PolicyID) AS TotalPolicies,

        ROUND(SUM(p.PremiumAmount),2) AS TotalPremium,

        COUNT(DISTINCT c.ClaimID) AS TotalClaims,

        ROUND(COALESCE(SUM(ca.ApprovedAmount),0),2) AS TotalApprovedAmount,

        SUM(
            CASE
                WHEN ca.FraudFlag='Yes'
                THEN 1
                ELSE 0
            END
        ) AS FraudCases

    FROM Agents a

    JOIN Policies p
        ON a.AgentID=p.AgentID

    JOIN Branches b
        ON a.BranchID=b.BranchID

    LEFT JOIN Claims c
        ON p.PolicyID=c.PolicyID

    LEFT JOIN claims_assessments ca
        ON c.ClaimID=ca.ClaimID

    GROUP BY
        a.AgentID,
        a.AgentName,
        b.BranchName
)

SELECT

    AgentID,

    AgentName,

    BranchName,

    TotalCustomers,

    TotalPolicies,

    TotalPremium,

    TotalClaims,

    TotalApprovedAmount,

    ROUND(
        (TotalApprovedAmount/
        NULLIF(TotalPremium,0))*100,
        2
    ) AS ClaimRatio,

    FraudCases,

    ROUND(
        TotalPremium-
        TotalApprovedAmount,
        2
    ) AS Profit,

    CASE

        WHEN
        (TotalApprovedAmount/
        NULLIF(TotalPremium,0))*100 <40
        THEN 'Excellent'

        WHEN
        (TotalApprovedAmount/
        NULLIF(TotalPremium,0))*100 BETWEEN 40 AND 60
        THEN 'Good'

        WHEN
        (TotalApprovedAmount/
        NULLIF(TotalPremium,0))*100 BETWEEN 60 AND 80
        THEN 'Average'

        ELSE 'Needs Review'

    END AS PerformanceCategory,

    DENSE_RANK() OVER
    (
        ORDER BY
        (TotalPremium-TotalApprovedAmount) DESC,
        FraudCases ASC
    ) AS PerformanceRank

FROM AgentPerformance

ORDER BY PerformanceRank;


/*==========================================================
SQL Concepts Demonstrated

✔ INNER JOIN
✔ LEFT JOIN
✔ Common Table Expressions (CTEs)
✔ Window Functions
✔ DENSE_RANK()
✔ CASE Statements
✔ Aggregate Functions
✔ Date Functions
✔ Conditional Aggregation
✔ Business KPI Calculations

==========================================================*/

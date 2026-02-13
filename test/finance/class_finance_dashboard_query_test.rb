# frozen_string_literal: true

require "test_helper"

class ClassFinanceDashboardQueryTest < ActiveSupport::TestCase
  setup do
    @training_class = TrainingClass.create!(
      title: "Finance Test Class",
      date: 1.week.from_now,
      location: "Test",
      price: 1000,
      cost: 200
    )
  end

  teardown do
    @training_class&.destroy
  end

  test "call returns all required keys" do
    result = Finance::ClassFinanceDashboardQuery.new(@training_class, {}).call
    %i[kpis waterfall profitability cost_by_category payment_status_list
       segment_split promotions_performance payment_intelligence insights].each do |key|
      assert result.key?(key), "missing key: #{key}"
    end
  end

  test "kpis include gross_sales, net_revenue_before_vat, cash_received, outstanding, net_profit" do
    result = Finance::ClassFinanceDashboardQuery.new(@training_class, {}).call
    k = result[:kpis]
    assert k.key?(:gross_sales)
    assert k.key?(:net_revenue_before_vat)
    assert k.key?(:cash_received)
    assert k.key?(:outstanding)
    assert k.key?(:net_profit)
    assert k.key?(:profit_margin_pct)
  end

  test "payment_status_list rows include days_to_pay and segment" do
    result = Finance::ClassFinanceDashboardQuery.new(@training_class, {}).call
    list = result[:payment_status_list]
    assert_respond_to list, :each
    list.each do |row|
      assert row.key?(:days_to_pay)
      assert row.key?(:segment)
      assert row.key?(:email)
      assert %w[Paid Pending Overdue].include?(row[:status])
    end
  end

  test "segment_split returns indi and corp with amount count seats" do
    result = Finance::ClassFinanceDashboardQuery.new(@training_class, {}).call
    seg = result[:segment_split]
    assert seg.key?(:indi)
    assert seg.key?(:corp)
    %i[amount count seats].each do |k|
      assert seg[:indi].key?(k)
      assert seg[:corp].key?(k)
    end
  end

  test "payment_intelligence includes collection_rate_pct and avg_days_to_pay" do
    result = Finance::ClassFinanceDashboardQuery.new(@training_class, {}).call
    pi = result[:payment_intelligence]
    assert pi.key?(:collection_rate_pct)
    assert pi.key?(:avg_days_to_pay)
    assert pi.key?(:pct_paid_under_7_days)
    assert pi.key?(:pct_late)
  end

  test "insights is an array" do
    result = Finance::ClassFinanceDashboardQuery.new(@training_class, {}).call
    assert_kind_of Array, result[:insights]
    assert result[:insights].length <= 5
  end
end

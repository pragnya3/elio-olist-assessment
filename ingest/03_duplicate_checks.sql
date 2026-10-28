SELECT 'dup_order_ids_in_orders' AS check_name,
       COUNT(*) - COUNT(DISTINCT order_id) AS result
FROM OLIST.RAW.ORDERS
UNION ALL
SELECT 'dup_review_ids_in_reviews',
       COUNT(*) - COUNT(DISTINCT review_id)
FROM OLIST.RAW.ORDER_REVIEWS
UNION ALL
SELECT 'orders_with_multiple_reviews',
       COUNT(*)
FROM (SELECT order_id FROM OLIST.RAW.ORDER_REVIEWS
      GROUP BY order_id HAVING COUNT(*) > 1);
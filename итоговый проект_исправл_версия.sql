
--1. Выведите названия самолётов, которые имеют менее 50 посадочных мест.

select model
from aircrafts a
join seats s on a.aircraft_code = s.aircraft_code --присоединяем таблицу с сидениями
group by s.aircraft_code, a.model --группируем по самолетам
having count(s.seat_no) < 50 --выбираем только самолеты с более 50 мест

--2. Выведите процентное изменение ежемесячной суммы бронирования билетов, округленной до сотых.

--используем coalesce для замены null на исходное значение, обозначенное как 100%
--узнаем процентное изменение по сравнению с предыдущим значением с помощью функции lag
select months, sum_for_months, coalesce(round ((sum_for_months - lag(sum_for_months, 1) over ()) / lag(sum_for_months, 1) over () * 100, 2), 100) as percentage_change
from (
select months, sum_for_months
from (
select date_trunc('month', book_date) as months, sum(total_amount) over (partition by months) as sum_for_months --узнаем сумму бронирования для каждого месяца
from (
select *, date_trunc('month', book_date) as months --оставляем даты на уровне месяцев чтобы сгруппировать
from bookings b
group by months, b.book_ref) as first_data
group by months, first_data.book_date, first_data.total_amount) as second_data
group by months, sum_for_months) as third_data

--3. Выведите названия самолётов без бизнес-класса. Используйте в решении функцию array_agg.

select model
from (
select model, array_agg(fare_conditions) conditions --превращаем данные в массив
from aircrafts a
join seats s on a.aircraft_code = s.aircraft_code
group by a.model) as cho
group by cho.model, cho.conditions
having array_position(conditions, 'Business') is null -- отбираем данные, в которых нет слова Business

/* 4. Выведите накопительный итог количества мест в самолётах по каждому аэропорту на каждый день.
 * Учтите только те самолеты, которые летали пустыми и только те дни, когда из одного аэропорта 
 * вылетело более одного такого самолёта. Выведите в результат код аэропорта, дату вылета, количество пустых мест и накопительный итог.
 */


--заменяем null на исходное значение, при поиске накопительного итога используем функцию sum
select flight_id, departure_airport, actual_departure, chislo_pustikh_mest, coalesce(sum(chislo_pustikh_mest) over (partition by days, departure_airport order by actual_departure), chislo_pustikh_mest) as nacop_itog
from (
select forth_sel.flight_id, forth_sel.aircraft_code, days, forth_sel.departure_airport, count, chislo_pustikh_mest, actual_departure
from (
select *
from (
select *
from (
select flight_id, aircraft_code, days, departure_airport, count(flight_id) over (partition by days, departure_airport), chislo_pustikh_mest
from (
select f.flight_id, f.aircraft_code, date_trunc('day', actual_departure) as days, departure_airport, count_seats as chislo_pustikh_mest
from flights f 
left join boarding_passes bp on bp.flight_id = f.flight_id
left join (select aircraft_code, count(seat_no) as count_seats
from seats s 
group by s.aircraft_code
order by s.aircraft_code) as s on s.aircraft_code = f.aircraft_code
where f.actual_departure is not null and bp.boarding_no is null --отбираем пустые места
group by days, f.flight_id, departure_airport, s.count_seats) as first_sel) as second_sel
where count > 1) as third_sel) as forth_sel --выбираем только дни, когда из аэропорта вылетало несколько самолетов
join flights f on f.flight_id = forth_sel.flight_id) as fifth_sel
group by fifth_sel.flight_id, fifth_sel.aircraft_code, fifth_sel.days, fifth_sel.departure_airport, fifth_sel.count, fifth_sel.chislo_pustikh_mest, fifth_sel.actual_departure


/*5. Найдите процентное соотношение перелётов по маршрутам от общего количества перелётов. 
*Выведите в результат названия аэропортов и процентное отношение.
*Используйте в решении оконную функцию.
*/

select direction, part_count * 1.0 / count_for_all as res --умножаем на 1.0, чтобы видеть цифры после запятой
from (
select departure_airport || '-' || arrival_airport as direction,
count(flight_id) over (partition by departure_airport, arrival_airport) * 100 as part_count, --считаем количество перелетов для каждого маршрута
(select count(flight_no) as count_for_all --считаем общее количество перелетов
from flights f)
from flights f) as two_counts 
group by direction, res

--6. Выведите количество пассажиров по каждому коду сотового оператора. Код оператора – это три символа после +7

select count(passenger_id) /*считаем количество пассажиров*/ as passengers, substring(telephone from 3 for 3) as codes --выделяем нужные нам цифры из номера
from (
select passenger_id, contact_data ->> 'phone' as telephone --выводим из json нужные нам данные
from tickets t) as phones
group by codes

/*7. Классифицируйте финансовые обороты (сумму стоимости билетов) по маршрутам:
*до 50 млн – low
*от 50 млн включительно до 150 млн – middle
*от 150 млн включительно – high
*Выведите в результат количество маршрутов в каждом полученном классе.
*/

select sum_type, count(sum_type) --считаем количество маршрутов для каждого типа 
from (select departure_airport || '-' || arrival_airport as direction,
CASE --ставим условие и группируем маршруты
      WHEN sum(tf.amount) < 50000000 THEN 'low'
      WHEN sum(tf.amount) >= 150000000 THEN 'high'
      ELSE 'middle'
    END AS sum_type
from flights f
join ticket_flights tf on f.flight_id = tf.flight_id 
group by direction) as classif
group by classif.sum_type

/*8. Вычислите медиану стоимости билетов, медиану стоимости бронирования и отношение медианы бронирования
*к медиане стоимости билетов, результат округлите до сотых. 
*/

select med_boo / med_tic as division_res --делим медианы
from (
select percentile_cont(0.5) WITHIN GROUP (ORDER BY amount) as med_tic, --узнаем медиану стоимости билетов
(select percentile_cont(0.5) WITHIN GROUP (ORDER BY total_amount) as med_boo --узнаем медиану строимости брони
from bookings)
from ticket_flights) as two_results

9.Найдите значение минимальной стоимости одного километра полёта для пассажира. 
Для этого определите расстояние между аэропортами и учтите стоимость билетов.

create extension cube

create extension earthdistance

select tf.min / (earth_distance(ll_to_earth(d.latitude, d.longitude), ll_to_earth (a.latitude, a.longitude)) / 1000)
from (
select flight_id, min(amount)
from ticket_flights 
group by flight_id) tf
join flights f on f.flight_id = tf.flight_id
join airports d on f.departure_airport = d.airport_code
join airports a on f.arrival_airport = a.airport_code
order by 1 
limit 1







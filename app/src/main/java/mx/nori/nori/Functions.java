package mx.nori.nori;

import java.lang.reflect.Field;
import java.text.DecimalFormat;
import java.text.NumberFormat;
import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Date;
import java.util.Locale;

public class Functions {
    public static String getCurrentDateTimeString() {
        Calendar calendar = Calendar.getInstance();
        SimpleDateFormat mdformat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
        return mdformat.format(calendar.getTime());
    }

    public static String toDateTimeString(Date date) {
        SimpleDateFormat mdformat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
        return mdformat.format(date.getTime());
    }

    public static String toDateString(Date date) {
        SimpleDateFormat mdformat = new SimpleDateFormat("yyyy-MM-dd");
        return mdformat.format(date.getTime());
    }

    public static Date getCurrentDateTime() {
        Calendar calendar = Calendar.getInstance();
        return calendar.getTime();
    }

    public static Date getCurrentDate() {
        Calendar calendar = Calendar.getInstance();
        calendar.set(Calendar.HOUR_OF_DAY, 0);
        return calendar.getTime();
    }

    public static Date getMinDateTime() {
        Calendar calendar = Calendar.getInstance();
        calendar.set(1991, 12, 18);
        return calendar.getTime();
    }

    public static String toCurrency(Double number)
    {
        return String.format(Locale.ENGLISH,"$%.2f", number);
    }

    public static Date addDays(Date date, int days)
    {
        Calendar cal = Calendar.getInstance();
        cal.setTime(date);
        cal.add(Calendar.DATE, days);
        return cal.getTime();
    }

    public static Calendar getCurrentCalendar() {
        Calendar calendar = Calendar.getInstance();
        return calendar;
    }

    public static void CopyObject(Object from, Object to) {
        Field[] fields = from.getClass().getDeclaredFields();
        for (Field field : fields) {
            try {
                Field fieldFrom = from.getClass().getDeclaredField(field.getName());
                Object value = fieldFrom.get(from);
                to.getClass().getDeclaredField(field.getName()).set(to, value);

            } catch (IllegalAccessException e) {
                e.printStackTrace();
            } catch (NoSuchFieldException e) {
                e.printStackTrace();
            }
        }
    }
}

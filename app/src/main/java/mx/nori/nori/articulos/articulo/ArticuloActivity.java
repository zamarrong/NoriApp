package mx.nori.nori.articulos.articulo;

import android.os.Bundle;
import android.support.design.widget.TabLayout;
import android.support.v4.view.ViewPager;
import android.support.v7.app.AppCompatActivity;

import mx.nori.nori.NoriSDK.Articulo;
import mx.nori.nori.R;
import mx.nori.nori.ViewPagerAdapter;

public class ArticuloActivity extends AppCompatActivity {

    private static Articulo articulo = new Articulo();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_articulo);
        TabLayout tabLayout = findViewById(R.id.tabLayout);
        ViewPager viewPager = findViewById(R.id.viewPager);

        loadViewPager(viewPager);
        tabLayout.setupWithViewPager(viewPager);

        Integer id = getIntent().getIntExtra("id", 0);
        articulo = Articulo.Obtener(id);
    }

    public static Articulo getArticulo() {
        return articulo;
    }

    private void loadViewPager(ViewPager viewPager) {
        ViewPagerAdapter adapter =  new ViewPagerAdapter(getSupportFragmentManager());
        adapter.addFragment(new ArticuloGeneralFragment(), "General");
        viewPager.setAdapter(adapter);
    }
}
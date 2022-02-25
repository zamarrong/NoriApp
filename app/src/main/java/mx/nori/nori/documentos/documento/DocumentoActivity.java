package mx.nori.nori.documentos.documento;

import android.os.Bundle;
import android.support.design.widget.TabLayout;
import android.support.v4.view.ViewPager;
import android.support.v7.app.AppCompatActivity;

import mx.nori.nori.NoriSDK.Documento;
import mx.nori.nori.NoriSDK.Global;
import mx.nori.nori.NoriSDK.Socio;
import mx.nori.nori.R;
import mx.nori.nori.ViewPagerAdapter;

public class DocumentoActivity extends AppCompatActivity {
    private static Documento documento;
    private static Socio socio;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_documento);

        int documento_id = getIntent().getIntExtra("id", 0);
        int socio_id = getIntent().getIntExtra("socio_id", 0);

        documento = new Documento();
        socio = new Socio();

        if (documento_id != 0) {
            documento = Documento.Obtener(documento_id);
        } else {
            documento.setClase(getIntent().getStringExtra("clase"));
        }

        if (socio_id == 0) {
            if (documento.getSocio_id() == 0) {
                socio = Socio.Obtener(Global.getUsuario().getSocio_id());
                documento.EstablecerSocio(socio);
            } else {
                socio = Socio.Obtener(documento.getSocio_id());
            }
        } else {
            socio = Socio.Obtener(socio_id);
            documento.EstablecerSocio(socio);
        }

        TabLayout tabLayout = findViewById(R.id.tabLayout);
        ViewPager viewPager = findViewById(R.id.viewPager);

        loadViewPager(viewPager);
        tabLayout.setupWithViewPager(viewPager);
    }

    public static Documento getDocumento() {
        return documento;
    }

    public static Socio getSocio() {
        return socio;
    }

    public static void setSocio(Socio socio) {
        DocumentoActivity.socio = socio;
        documento.EstablecerSocio(socio);
    }

    private void loadViewPager(ViewPager viewPager) {
        ViewPagerAdapter adapter =  new ViewPagerAdapter(getSupportFragmentManager());
        adapter.addFragment(new DocumentoGeneralFragment(), "General");
        if (documento.getClase().equals("ST") || documento.getClase().equals("TS") || documento.getClase().equals("IF")) {
            if (documento.getClase().equals("IF")) {
                adapter.addFragment(new DocumentoPartidasIFFragment(), "Partidas");
            } else {
                adapter.addFragment(new DocumentoPartidasFragment(), "Partidas");
            }
        } else {
            if (Global.getConfiguracion().getModo_rapido()) {
                adapter.addFragment(new DocumentoPartidasTablaFragment(), "Partidas");
            } else {
                adapter.addFragment(new DocumentoPartidasFragment(), "Partidas");
            }
        }
        if (documento.getClase().equals("EN") || documento.getClase().equals("FA")) {
            adapter.addFragment(new DocumentoMediosPagoFragment(), "Pago");
        }
        adapter.addFragment(new DocumentoRevisionFragment(), "Revisión");
        viewPager.setAdapter(adapter);
    }
}